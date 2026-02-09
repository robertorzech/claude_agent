-- ===========================================================
-- Analiza testu AB z izolacją
-- Źródło: ga4_events (Superform Labs Dataform)
-- Parametry do uzupełnienia:
--   @test_id  = np. 'TABW131'
--   @start_date, @end_date = zakres dat
-- ===========================================================

WITH
-- Krok 1: Identyfikacja użytkowników w teście
-- Źródło: event_params_custom.test_ab (format: "TABW131_a", "TABW131_b")
-- lub item_parameter_20 (format: "test:_TABW131_ab:_a_qs:_segment")
test_users AS (
  SELECT DISTINCT
    user_pseudo_id,
    -- Wyciągnij grupę z event-level test_ab
    REGEXP_EXTRACT(event_params_custom.test_ab, r'@test_id_(\w+)') AS test_group
  FROM `{PROJECT}.{DATASET}.ga4_events`
  WHERE
    event_date BETWEEN @start_date AND @end_date
    AND event_params_custom.test_ab LIKE CONCAT(@test_id, '%')
    AND REGEXP_EXTRACT(event_params_custom.test_ab, r'@test_id_(\w+)') IS NOT NULL
),

-- Krok 2: Izolacja — wyklucz userów w innych testach AB
users_in_other_tests AS (
  SELECT DISTINCT user_pseudo_id
  FROM `{PROJECT}.{DATASET}.ga4_events`
  WHERE
    event_date BETWEEN @start_date AND @end_date
    AND event_params_custom.test_ab IS NOT NULL
    AND event_params_custom.test_ab NOT LIKE CONCAT(@test_id, '%')
),

isolated_test_users AS (
  SELECT t.*
  FROM test_users t
  LEFT JOIN users_in_other_tests o USING (user_pseudo_id)
  WHERE o.user_pseudo_id IS NULL  -- anti-join: wyklucz userów w innych testach
),

-- Krok 3: Zbierz eventy dla izolowanych userów
test_events AS (
  SELECT
    e.event_name,
    e.event_date,
    e.session_id,
    e.user_pseudo_id,
    e.device.category AS device_category,
    e.ecommerce.purchase_revenue,
    e.ecommerce.transaction_id,
    t.test_group
  FROM `{PROJECT}.{DATASET}.ga4_events` e
  INNER JOIN isolated_test_users t USING (user_pseudo_id)
  WHERE e.event_date BETWEEN @start_date AND @end_date
),

-- Krok 4: Walidacja splitów
split_validation AS (
  SELECT
    test_group,
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(DISTINCT session_id) AS sessions
  FROM test_events
  GROUP BY test_group
),

split_check AS (
  SELECT
    *,
    users / SUM(users) OVER () AS user_share,
    -- Flagowanie: split powinien być 45-55%
    CASE
      WHEN users / SUM(users) OVER () BETWEEN 0.45 AND 0.55 THEN 'OK'
      ELSE '⚠️ NIERÓWNY SPLIT'
    END AS split_status
  FROM split_validation
),

-- Krok 5: Metryki per grupa
metrics_per_group AS (
  SELECT
    test_group,
    device_category,

    -- Sesje i użytkownicy
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(DISTINCT session_id) AS sessions,

    -- Funnel steps
    COUNT(DISTINCT IF(event_name = 'session_start', session_id, NULL)) AS sessions_start,
    COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL)) AS users_view_item,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS users_add_to_cart,
    COUNT(DISTINCT IF(event_name = 'begin_checkout', user_pseudo_id, NULL)) AS users_begin_checkout,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS users_purchase,

    -- Revenue
    SUM(IF(event_name = 'purchase', purchase_revenue, 0)) AS total_revenue,
    COUNT(DISTINCT IF(event_name = 'purchase', transaction_id, NULL)) AS transactions

  FROM test_events
  GROUP BY test_group, device_category
),

-- Krok 6: Obliczenie KPIs
results AS (
  SELECT
    *,

    -- Conversion rates
    SAFE_DIVIDE(users_add_to_cart, users_view_item) AS cr_pdp_to_cart,
    SAFE_DIVIDE(users_begin_checkout, users_add_to_cart) AS cr_cart_to_checkout,
    SAFE_DIVIDE(users_purchase, sessions) AS cr_session_to_purchase,
    SAFE_DIVIDE(users_purchase, users_view_item) AS cr_pdp_to_purchase,

    -- Revenue metrics
    SAFE_DIVIDE(total_revenue, sessions) AS revenue_per_session,
    SAFE_DIVIDE(total_revenue, transactions) AS aov,

    -- Items per transaction
    SAFE_DIVIDE(transactions, users_purchase) AS transactions_per_buyer

  FROM metrics_per_group
)

-- Wynik końcowy: metryki + walidacja splitów
SELECT
  r.*,
  sc.user_share,
  sc.split_status
FROM results r
LEFT JOIN split_check sc USING (test_group)
ORDER BY test_group, device_category;


-- ===========================================================
-- BONUS: Statystyczny test chi-square dla CR
-- Uruchom osobno po uzyskaniu wyników
-- ===========================================================
/*
-- Prosty test proporcji (z-test / chi-square approximation)
-- Zamień wartości na wyniki z powyższego query

WITH test_data AS (
  SELECT
    -- Grupa A (kontrola)
    1000 AS sessions_a,
    50 AS conversions_a,
    -- Grupa B (wariant)
    1020 AS sessions_b,
    62 AS conversions_b
),

calculations AS (
  SELECT
    *,
    conversions_a / sessions_a AS cr_a,
    conversions_b / sessions_b AS cr_b,
    (conversions_a + conversions_b) / (sessions_a + sessions_b) AS pooled_cr
  FROM test_data
),

z_score AS (
  SELECT
    *,
    (cr_b - cr_a) / SQRT(pooled_cr * (1 - pooled_cr) * (1.0/sessions_a + 1.0/sessions_b)) AS z_value,
    -- Relative uplift
    SAFE_DIVIDE(cr_b - cr_a, cr_a) AS relative_uplift
  FROM calculations
)

SELECT
  *,
  -- z > 1.96 = p < 0.05 (statystycznie istotne)
  CASE
    WHEN ABS(z_value) > 2.576 THEN '✅ p < 0.01 (wysoka istotność)'
    WHEN ABS(z_value) > 1.96 THEN '✅ p < 0.05 (istotne statystycznie)'
    WHEN ABS(z_value) > 1.645 THEN '⚠️ p < 0.10 (marginalnie istotne)'
    ELSE '❌ Nieistotne statystycznie'
  END AS significance
FROM z_score;
*/

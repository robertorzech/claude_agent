-- ===========================================================
-- Funnel Analysis: Pełny lejek e-commerce
-- Segmentacja: device, channel, user_type
-- Metryki: users, step CR, overall CR, drop-off, median time
-- Źródło: ga4_events + ga4_sessions (Superform Labs Dataform)
-- ===========================================================

-- Parametry (zamień na konkretne wartości lub użyj @params):
-- @start_date = DATE '2026-01-01'
-- @end_date = DATE '2026-01-31'
-- {PROJECT}.{DATASET} = Twój project.dataset

WITH
-- Krok 0: Bazowa tabela z sesją i wymiarami segmentacji
base_events AS (
  SELECT
    e.event_name,
    e.event_date,
    e.session_id,
    e.user_pseudo_id,
    e.time.event_timestamp,
    e.device.category AS device_category,
    IF(e.event_params.ga_session_number = 1, 'New', 'Returning') AS user_type,
    -- Channel wymaga joina z ga4_sessions
    s.last_non_direct_traffic_source.default_channel_grouping AS channel
  FROM `{PROJECT}.{DATASET}.ga4_events` e
  LEFT JOIN `{PROJECT}.{DATASET}.ga4_sessions` s
    ON e.session_id = s.session_id
  WHERE
    e.event_date BETWEEN @start_date AND @end_date
    AND e.event_name IN (
      'session_start',
      'view_item_list',
      'view_item',
      'add_to_cart',
      'begin_checkout',
      'add_shipping_info',
      'purchaseOnClick',
      'purchase'
    )
),

-- Krok 1: Pivot — dla każdego usera+sesji, najwcześniejszy timestamp per event
user_funnel_flags AS (
  SELECT
    user_pseudo_id,
    session_id,
    device_category,
    user_type,
    channel,
    -- Flagowanie kroków (1 = użytkownik wykonał krok w tej sesji)
    MAX(IF(event_name = 'session_start', 1, 0)) AS step_session_start,
    MAX(IF(event_name = 'view_item_list', 1, 0)) AS step_view_item_list,
    MAX(IF(event_name = 'view_item', 1, 0)) AS step_view_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS step_add_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS step_begin_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS step_add_shipping_info,
    MAX(IF(event_name = 'purchaseOnClick', 1, 0)) AS step_purchase_on_click,
    MAX(IF(event_name = 'purchase', 1, 0)) AS step_purchase,
    -- Timestamps (do obliczenia czasu między krokami)
    MIN(IF(event_name = 'session_start', event_timestamp, NULL)) AS ts_session_start,
    MIN(IF(event_name = 'view_item_list', event_timestamp, NULL)) AS ts_view_item_list,
    MIN(IF(event_name = 'view_item', event_timestamp, NULL)) AS ts_view_item,
    MIN(IF(event_name = 'add_to_cart', event_timestamp, NULL)) AS ts_add_to_cart,
    MIN(IF(event_name = 'begin_checkout', event_timestamp, NULL)) AS ts_begin_checkout,
    MIN(IF(event_name = 'add_shipping_info', event_timestamp, NULL)) AS ts_add_shipping_info,
    MIN(IF(event_name = 'purchaseOnClick', event_timestamp, NULL)) AS ts_purchase_on_click,
    MIN(IF(event_name = 'purchase', event_timestamp, NULL)) AS ts_purchase
  FROM base_events
  GROUP BY user_pseudo_id, session_id, device_category, user_type, channel
),

-- Krok 2: Agregacja per segment
funnel_aggregated AS (
  SELECT
    device_category,
    user_type,
    channel,

    -- Liczba użytkowników per krok
    COUNT(DISTINCT IF(step_session_start = 1, user_pseudo_id, NULL)) AS users_session_start,
    COUNT(DISTINCT IF(step_view_item_list = 1, user_pseudo_id, NULL)) AS users_view_item_list,
    COUNT(DISTINCT IF(step_view_item = 1, user_pseudo_id, NULL)) AS users_view_item,
    COUNT(DISTINCT IF(step_add_to_cart = 1, user_pseudo_id, NULL)) AS users_add_to_cart,
    COUNT(DISTINCT IF(step_begin_checkout = 1, user_pseudo_id, NULL)) AS users_begin_checkout,
    COUNT(DISTINCT IF(step_add_shipping_info = 1, user_pseudo_id, NULL)) AS users_add_shipping_info,
    COUNT(DISTINCT IF(step_purchase_on_click = 1, user_pseudo_id, NULL)) AS users_purchase_on_click,
    COUNT(DISTINCT IF(step_purchase = 1, user_pseudo_id, NULL)) AS users_purchase,

    -- Mediana czasu między krokami (w minutach)
    APPROX_QUANTILES(
      IF(ts_view_item_list IS NOT NULL AND ts_session_start IS NOT NULL,
         (ts_view_item_list - ts_session_start) / 60000000, NULL), 100
    )[OFFSET(50)] AS median_min_start_to_listing,

    APPROX_QUANTILES(
      IF(ts_view_item IS NOT NULL AND ts_view_item_list IS NOT NULL,
         (ts_view_item - ts_view_item_list) / 60000000, NULL), 100
    )[OFFSET(50)] AS median_min_listing_to_pdp,

    APPROX_QUANTILES(
      IF(ts_add_to_cart IS NOT NULL AND ts_view_item IS NOT NULL,
         (ts_add_to_cart - ts_view_item) / 60000000, NULL), 100
    )[OFFSET(50)] AS median_min_pdp_to_cart,

    APPROX_QUANTILES(
      IF(ts_begin_checkout IS NOT NULL AND ts_add_to_cart IS NOT NULL,
         (ts_begin_checkout - ts_add_to_cart) / 60000000, NULL), 100
    )[OFFSET(50)] AS median_min_cart_to_checkout,

    APPROX_QUANTILES(
      IF(ts_purchase IS NOT NULL AND ts_begin_checkout IS NOT NULL,
         (ts_purchase - ts_begin_checkout) / 60000000, NULL), 100
    )[OFFSET(50)] AS median_min_checkout_to_purchase

  FROM user_funnel_flags
  GROUP BY device_category, user_type, channel
),

-- Krok 3: Obliczenie conversion rates
funnel_with_rates AS (
  SELECT
    *,
    -- Step-to-step CR
    SAFE_DIVIDE(users_view_item_list, users_session_start) AS cr_start_to_listing,
    SAFE_DIVIDE(users_view_item, users_view_item_list) AS cr_listing_to_pdp,
    SAFE_DIVIDE(users_add_to_cart, users_view_item) AS cr_pdp_to_cart,
    SAFE_DIVIDE(users_begin_checkout, users_add_to_cart) AS cr_cart_to_checkout,
    SAFE_DIVIDE(users_add_shipping_info, users_begin_checkout) AS cr_checkout_step1_to_step2,
    SAFE_DIVIDE(users_purchase_on_click, users_add_shipping_info) AS cr_step2_to_pay_click,
    SAFE_DIVIDE(users_purchase, users_purchase_on_click) AS cr_pay_click_to_purchase,

    -- Overall CR (od session_start)
    SAFE_DIVIDE(users_view_item_list, users_session_start) AS overall_cr_listing,
    SAFE_DIVIDE(users_view_item, users_session_start) AS overall_cr_pdp,
    SAFE_DIVIDE(users_add_to_cart, users_session_start) AS overall_cr_cart,
    SAFE_DIVIDE(users_begin_checkout, users_session_start) AS overall_cr_checkout,
    SAFE_DIVIDE(users_purchase, users_session_start) AS overall_cr_purchase,

    -- Drop-off rates
    1 - SAFE_DIVIDE(users_view_item_list, users_session_start) AS dropoff_start_to_listing,
    1 - SAFE_DIVIDE(users_view_item, users_view_item_list) AS dropoff_listing_to_pdp,
    1 - SAFE_DIVIDE(users_add_to_cart, users_view_item) AS dropoff_pdp_to_cart,
    1 - SAFE_DIVIDE(users_begin_checkout, users_add_to_cart) AS dropoff_cart_to_checkout,
    1 - SAFE_DIVIDE(users_purchase, users_begin_checkout) AS dropoff_checkout_to_purchase

  FROM funnel_aggregated
)

SELECT *
FROM funnel_with_rates
ORDER BY device_category, user_type, channel

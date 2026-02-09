-- ===========================================================
-- Biblioteka CTE do parsowania item_parameter_X
-- Dla: ga4_events z GA4 Dataform Package (Superform Labs)
-- Repozytorium: robertorzech/ga4-superformlabs
--
-- Użycie: Kopiuj potrzebne CTE do swoich zapytań.
-- Jeśli item_params są w CUSTOM_ITEM_PARAMS_ARRAY,
-- użyj wersji z item_params_custom (prostsza).
-- ===========================================================

-- ============================================
-- WERSJA A: item_params_custom (jeśli skonfigurowane w Dataform config.js)
-- ============================================

-- CTE: Parsowanie cen (item_parameter_1)
-- Użycie: Wyciąga cenę per osoba, per pokój, typ wyświetlania, cenę z cross-sellami
WITH parsed_prices AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_name,
    i.item_brand,
    i.item_params_custom.item_parameter_1 AS raw_param_1,

    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_1, r'per:_(\d+)') AS INT64) AS price_per_person,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_1, r'room:_(\d+)') AS INT64) AS price_per_room,
    REGEXP_EXTRACT(i.item_params_custom.item_parameter_1, r'filter:_(\w+)') AS price_display_type,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_1, r'summary:_(\d+)') AS INT64) AS price_summary,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_1, r'listing_price:_(\d+)') AS INT64) AS listing_price

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
),

-- CTE: Parsowanie czasu trwania i dni do wyjazdu (item_parameter_5)
parsed_trip_details AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_params_custom.item_parameter_5 AS raw_param_5,

    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_5, r'd:_(\d+)') AS INT64) AS trip_duration_days,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_5, r'dtt:_(\d+)') AS INT64) AS days_to_trip,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_5, r'offers:_(\d+)') AS INT64) AS listing_offers_count

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
),

-- CTE: Parsowanie konfiguracji osobowej (item_parameter_9)
parsed_participants AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_params_custom.item_parameter_9 AS raw_param_9,

    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_9, r'(?:adult|a):_(\d+)') AS INT64) AS adults_count,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_9, r'(?:child|c):_(\d+)') AS INT64) AS children_count

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
),

-- CTE: Parsowanie dostępności cross-sell (item_parameter_19)
parsed_cross_sell_availability AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_params_custom.item_parameter_19 AS raw_param_19,

    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_19, r'^p:_(\d)') AS INT64) AS parking_available,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_19, r'i:_(\d)') AS INT64) AS insurance_available,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_19, r'pr:_(\d)') AS INT64) AS promesa_available,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_19, r'l:_(\d)') AS INT64) AS luggage_available,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_19, r's:_(\d)') AS INT64) AS seats_together_available

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
),

-- CTE: Parsowanie testu AB + QS (item_parameter_20)
parsed_ab_test AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_params_custom.item_parameter_20 AS raw_param_20,

    REGEXP_EXTRACT(i.item_params_custom.item_parameter_20, r'test:_(\w+)') AS test_id,
    REGEXP_EXTRACT(i.item_params_custom.item_parameter_20, r'ab:_(\w+)') AS test_group,
    REGEXP_EXTRACT(i.item_params_custom.item_parameter_20, r'qs:_(\w+)') AS qs_segment

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
),

-- CTE: Parsowanie wybranych cross-selli (item_parameter_25)
parsed_cross_sell_selected AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_params_custom.item_parameter_25 AS raw_param_25,

    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'^p:_(\d)') AS INT64) AS parking_selected,
    REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'^p:_\d-(.+?)_i:') AS parking_name,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'i:_(\d)') AS INT64) AS insurance_selected,
    REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'i:_\d-(.+?)_pr:') AS insurance_name,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'pr:_(\d)') AS INT64) AS promesa_selected,
    SAFE_CAST(REGEXP_EXTRACT(i.item_params_custom.item_parameter_25, r'l:_(\d)') AS INT64) AS luggage_selected

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
)

-- Użycie końcowe:
-- SELECT * FROM parsed_prices WHERE event_name = 'view_item' LIMIT 100;


-- ============================================
-- WERSJA B: surowy item_params (jeśli NIE skonfigurowane w Dataform)
-- Wolniejsza, ale nie wymaga zmian w config.js
-- ============================================

/*
WITH parsed_prices_raw AS (
  SELECT
    event_date,
    event_name,
    session_id,
    user_pseudo_id,
    i.item_id,
    i.item_name,

    (SELECT value.string_value FROM UNNEST(i.item_params) WHERE key = 'item_parameter_1') AS raw_param_1,

    SAFE_CAST(REGEXP_EXTRACT(
      (SELECT value.string_value FROM UNNEST(i.item_params) WHERE key = 'item_parameter_1'),
      r'per:_(\d+)'
    ) AS INT64) AS price_per_person,

    SAFE_CAST(REGEXP_EXTRACT(
      (SELECT value.string_value FROM UNNEST(i.item_params) WHERE key = 'item_parameter_1'),
      r'room:_(\d+)'
    ) AS INT64) AS price_per_room

  FROM `{PROJECT}.{DATASET}.ga4_events` e,
  UNNEST(items) AS i
  WHERE event_date BETWEEN @start_date AND @end_date
)
*/

# Schemat tabeli ga4_events (Superform Labs GA4 Dataform Package)

## Źródło
Tabela `ga4_events` jest generowana przez [GA4 Dataform Package](https://github.com/robertorzech/ga4-superformlabs).
Jest to tabela incremental, partycjonowana po `event_date`, klastrowana po `event_name` i `session_id`.

## Struktura kolumn

### Kolumny bazowe
- `event_name` — nazwa zdarzenia GA4
- `event_date` — data zdarzenia (DATE, partycja)
- `table_suffix` — suffix oryginalnej tabeli GA4
- `is_final` — czy dane są finalne (po DATA_IS_FINAL_DAYS)
- `user_pseudo_id` — identyfikator użytkownika (cookie-based)
- `user_id` — identyfikator zalogowanego użytkownika (nullable)
- `is_active_user` — czy użytkownik aktywny
- `event_id` — unikalny ID zdarzenia (FARM_FINGERPRINT)
- `session_id` — identyfikator sesji
- `property_id` — ID property GA4
- `stream_id` — ID strumienia danych
- `platform` — platforma (Web, IOS, Android)

### Struct: time
- `time.event_timestamp` — timestamp zdarzenia (UNIX microseconds)
- `time.event_timestamp_utc` — timestamp jako TIMESTAMP
- `time.user_first_touch_timestamp` — pierwszy kontakt
- `time.user_first_touch_timestamp_utc` — pierwszy kontakt jako TIMESTAMP
- `time.date_local` — data lokalna

### Struct: event_params
Unnestowane parametry zdarzeń (najważniejsze):
- `event_params.ga_session_id` — ID sesji GA4
- `event_params.ga_session_number` — numer sesji użytkownika
- `event_params.page_location` — URL strony
- `event_params.page_referrer` — referrer
- `event_params.page_title` — tytuł strony
- `event_params.engagement_time_msec` — czas zaangażowania
- `event_params.entrances` — czy entrance
- `event_params.session_engaged` — czy sesja zaangażowana
- `event_params.source` / `medium` / `campaign` — parametry kampanii
- `event_params.content_group` / `content_type` — grupowanie treści
- `event_params.currency` / `coupon` — e-commerce

### Struct: event_params_custom
Custom event params zdefiniowane w `CUSTOM_EVENT_PARAMS_ARRAY` w config.js.
Na Wakacje.pl mogą tu być np.:
- parametry testów AB
- page_type
- virtual_page

### Struct: privacy_info
- `privacy_info.analytics_storage` — status zgody analytics
- `privacy_info.ads_storage` — status zgody ads
- `privacy_info.uses_transient_token` — czy token tymczasowy

### Struct: collected_traffic_source
- `collected_traffic_source.manual_source` / `manual_medium` / `manual_campaign_name`
- `collected_traffic_source.gclid` / `dclid` / `srsltid`

### Struct: device
- `device.category` — desktop / mobile / tablet
- `device.operating_system`
- `device.browser`
- `device.language`
- `device.web_info.hostname`
- `device.web_info.browser`

### Struct: geo
- `geo.continent` / `geo.country` / `geo.region` / `geo.city`

### Struct: ecommerce
- `ecommerce.transaction_id`
- `ecommerce.purchase_revenue` / `purchase_revenue_in_usd`
- `ecommerce.refund_value` / `refund_value_in_usd`
- `ecommerce.shipping_value` / `tax_value`
- `ecommerce.total_item_quantity` / `unique_items`

### Array: items (REPEATED)
Każdy element items zawiera:
- `item_id` / `item_name` / `item_brand` / `item_variant`
- `item_category` / `item_category2` / `item_category3` / `item_category4` / `item_category5`
- `price` / `price_in_usd`
- `quantity`
- `item_revenue` / `item_revenue_in_usd`
- `item_refund` / `item_refund_in_usd`
- `coupon` / `affiliation`
- `item_list_id` / `item_list_name` / `item_list_index`
- `promotion_id` / `promotion_name` / `creative_name` / `creative_slot`
- `location_id`

#### items.item_params (nested REPEATED)
Standardowe item params + custom item params z `CUSTOM_ITEM_PARAMS_ARRAY`.
Dostęp: `(SELECT value.string_value FROM UNNEST(i.item_params) WHERE key = 'item_parameter_X')`

#### items.item_params_custom (struct, jeśli skonfigurowane)
Custom item dimensions z CUSTOM_ITEM_PARAMS_ARRAY — dostępne jako named columns.

### Struct: url_params
Wyciągnięte z page_location:
- `url_params.utm_source` / `utm_medium` / `utm_campaign` / `utm_id`
- `url_params.utm_content` / `utm_term`
- `url_params.utm_marketing_tactic` / `utm_source_platform` / `utm_creative_format`
- `url_params.gtm_debug` / `url_params._gl`

### Struct: url_params_custom
Custom URL params z `CUSTOM_URL_PARAMS_ARRAY`.

### Struct: page
- `page.location` — pełny URL (z event_params.page_location)
- `page.hostname`
- `page.path`

### Struct: batch
- `batch.batch_event_index` / `batch.batch_ordering_id` / `batch.batch_page_id`

## Powiązane tabele (z tego samego pakietu)

### ga4_sessions
Tabela sesji z agregatami. Kluczowe pola:
- `session_id`, `session_date`, `ga_session_number`
- `session_info.is_engaged_session`, `session_info.is_direct_session`
- `last_non_direct_traffic_source.*` (source, medium, campaign, default_channel_grouping)
- `session_traffic_source_last_click.*`
- `device.*`, `geo.*`

### ga4_transactions
Tabela transakcji z item totals i running totals:
- `transaction_id`, `transaction_date`
- `ecommerce.*` (revenue, shipping, tax)
- `items` (nested)
- `item_totals.*` (quantity, item_revenue, coupons)

## Konfiguracja custom parametrów

Plik: `includes/custom/modules/ga4/config.js`

```javascript
// Dodawanie custom event params:
CUSTOM_EVENT_PARAMS_ARRAY: [
    { name: "page_type", type: "string" },
    { name: "test_ab", type: "string" },
    { name: "virtual_page", type: "string" }
],

// Dodawanie custom item params (pojawią się w items.item_params_custom.*):
CUSTOM_ITEM_PARAMS_ARRAY: [
    { name: "item_parameter_1", type: "string" },
    { name: "item_parameter_5", type: "string" },
    { name: "item_parameter_9", type: "string" },
    { name: "item_parameter_19", type: "string" },
    { name: "item_parameter_20", type: "string" },
    { name: "item_parameter_25", type: "string" }
],

// Custom URL params:
CUSTOM_URL_PARAMS_ARRAY: [
    { name: "search_query", cleaningMethod: lowerSQL }
],
```

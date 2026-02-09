# Dokumentacja item_parameter_X — Wakacje.pl / TPPL / Invia

## Przegląd

Parametry item_parameter_1 do item_parameter_25 zawierają zakodowane dane o ofercie turystycznej.
Są przechowywane w `items.item_params` (key-value) lub `items.item_params_custom` (jeśli skonfigurowane w Dataform).

Formaty używają separatora `_` po kluczu, np. `per:_1234_room:_5678`.

---

## item_parameter_1 — Ceny oferty

**Format:** `per:_XXXX_room:_YYYY_filter:_ZZZ_summary:_WWWW_listing_price:_VVVV`

| Klucz | Opis | Typ |
|-------|------|-----|
| `per` | Cena za osobę dorosłą (PLN/CZK/EUR) | INT |
| `room` | Cena za pokój | INT |
| `filter` | Sposób prezentacji ceny: `person` lub `total` | STRING |
| `summary` | Cena z cross-sellami (ubezp., parking itp.) | INT |
| `listing_price` | Cena wyświetlona na listingu | INT |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'per:_(\d+)')         -- price_per_person
REGEXP_EXTRACT(param, r'room:_(\d+)')        -- price_per_room
REGEXP_EXTRACT(param, r'filter:_(\w+)')      -- price_display_type
REGEXP_EXTRACT(param, r'summary:_(\d+)')     -- price_summary
REGEXP_EXTRACT(param, r'listing_price:_(\d+)') -- listing_price
```

---

## item_parameter_5 — Czas trwania i dni do wyjazdu

**Format:** `d:_X_dtt:_Y_offers:_Z`

| Klucz | Opis | Typ |
|-------|------|-----|
| `d` | Czas trwania wycieczki (dni) | INT |
| `dtt` | Dni do wyjazdu (days to trip) | INT |
| `offers` | Liczba ofert na listingu | INT |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'd:_(\d+)')       -- trip_duration_days
REGEXP_EXTRACT(param, r'dtt:_(\d+)')     -- days_to_trip
REGEXP_EXTRACT(param, r'offers:_(\d+)')  -- listing_offers_count
```

---

## item_parameter_9 — Konfiguracja osobowa (participants)

**Format:** `adult:_X_child:_Y` lub `a:_X_c:_Y`

| Klucz | Opis | Typ |
|-------|------|-----|
| `adult` / `a` | Liczba dorosłych | INT |
| `child` / `c` | Liczba dzieci | INT |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'(?:adult|a):_(\d+)')  -- adults_count
REGEXP_EXTRACT(param, r'(?:child|c):_(\d+)')  -- children_count
```

---

## item_parameter_19 — Dostępność cross-sell

**Format:** `p:_X_i:_Y_pr:_Z_l:_W_s:_V`

| Klucz | Opis | Wartości |
|-------|------|---------|
| `p` | Parking | 0/1 |
| `i` | Ubezpieczenie | 0/1 |
| `pr` | Promesa | 0/1 |
| `l` | Bagaże (luggage) | 0/1 |
| `s` | Miejsca obok siebie (seats together) | 0/1 |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'^p:_(\d)')     -- parking_available
REGEXP_EXTRACT(param, r'i:_(\d)')      -- insurance_available
REGEXP_EXTRACT(param, r'pr:_(\d)')     -- promesa_available
REGEXP_EXTRACT(param, r'l:_(\d)')      -- luggage_available
REGEXP_EXTRACT(param, r's:_(\d)')      -- seats_together_available
```

---

## item_parameter_20 — Test AB + QS variant

**Format:** `test:_ID_ab:_GRUPA_qs:_SEGMENT`

| Klucz | Opis | Typ |
|-------|------|-----|
| `test` | ID testu AB (np. TABW131) | STRING |
| `ab` | Grupa testowa (a=kontrola, b=wariant) | STRING |
| `qs` | Segment QS | STRING |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'test:_(\w+)')  -- test_id
REGEXP_EXTRACT(param, r'ab:_(\w+)')    -- test_group
REGEXP_EXTRACT(param, r'qs:_(\w+)')    -- qs_segment
```

---

## item_parameter_25 — Wybrane cross-selle

**Format:** `p:_X-NazwaP_i:_Y-NazwaU_pr:_Z_l:_W`

| Klucz | Opis | Typ |
|-------|------|-----|
| `p` | Parking: 0/1 + nazwa parkingu | STRING |
| `i` | Ubezpieczenie: 0/1 + nazwa ubezpieczenia | STRING |
| `pr` | Promesa: 0/1 | INT |
| `l` | Bagaże: 0/1 | INT |

**Regex:**
```sql
REGEXP_EXTRACT(param, r'^p:_(\d)')            -- parking_selected
REGEXP_EXTRACT(param, r'^p:_\d-(.+?)_i:')     -- parking_name
REGEXP_EXTRACT(param, r'i:_(\d)')             -- insurance_selected
REGEXP_EXTRACT(param, r'i:_\d-(.+?)_pr:')     -- insurance_name
REGEXP_EXTRACT(param, r'pr:_(\d)')            -- promesa_selected
REGEXP_EXTRACT(param, r'l:_(\d)')             -- luggage_selected
```

---

## Uwagi implementacyjne

1. **Dostęp do item_params w ga4_events (Dataform):**
   - Jeśli skonfigurowane w `CUSTOM_ITEM_PARAMS_ARRAY`:
     ```sql
     SELECT i.item_params_custom.item_parameter_1
     FROM `ga4_events`, UNNEST(items) AS i
     ```
   - Jeśli NIE skonfigurowane (surowy item_params):
     ```sql
     SELECT (SELECT value.string_value FROM UNNEST(i.item_params) WHERE key = 'item_parameter_1')
     FROM `ga4_events`, UNNEST(items) AS i
     ```

2. **SAFE_CAST:** Zawsze używaj `SAFE_CAST(... AS INT64)` przy parsowaniu liczbowych wartości — chroni przed NULL/NaN.

3. **Walidacja:** Nie wszystkie parametry są obecne w każdym zdarzeniu. `item_parameter_1` jest typowo dostępny od `view_item`, ale nie w `view_item_list`.

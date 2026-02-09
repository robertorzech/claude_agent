# Definicja lejka e-commerce — Wakacje.pl / TPPL / Invia

## Kroki lejka (główny flow zakupowy)

| Krok | Event name | Opis | Uwagi |
|------|-----------|------|-------|
| 1 | `session_start` | Rozpoczęcie sesji | Bazowy krok, 100% |
| 2 | `view_item_list` | Wyświetlenie listingu ofert | ⚠️ Invia: wielokrotne per scroll |
| 3 | `select_item` | Kliknięcie oferty na listingu | Opcjonalny krok |
| 4 | `view_item` | Wyświetlenie PO (prezentacja oferty / PDP) | Kluczowy krok |
| 5 | `add_to_cart` | Klik "Kup teraz" / "Zarezerwuj wstępnie" | Nie ma klasycznego koszyka |
| 6 | `begin_checkout` | Wyświetlenie kroku I ŚR (ścieżka rezerwacji) | Checkout step 1 |
| 7 | `add_shipping_info` | Wyświetlenie kroku II ŚR (dane osobowe) | C1 = lead |
| 8 | `purchaseOnClick` | Kliknięcie "Zapłać" (krok IV ŚR) | Custom event |
| 9 | `purchase` | Wyświetlenie TYP (Thank You Page) | C2 = sprzedaż |

## Metryki per krok

### Podstawowe
- `users` — COUNT(DISTINCT user_pseudo_id)
- `sessions` — COUNT(DISTINCT session_id)
- `events` — COUNT(*)

### Conversion rates
- `step_cr` — % użytkowników z poprzedniego kroku (step-to-step)
- `overall_cr` — % użytkowników z session_start (overall)
- `drop_off_rate` — 1 - step_cr (kto odpada)

### Zaawansowane
- `median_time_to_next_step` — mediana czasu między krokami (minuty)
- `avg_time_to_next_step` — średni czas między krokami (minuty)

## Wymiary segmentacji

| Wymiar | Kolumna w ga4_events | Wartości |
|--------|---------------------|----------|
| Device | `device.category` | desktop, mobile, tablet |
| User type | `ga_session_number = 1` → New, else Returning | New / Returning |
| Channel | `last_non_direct_traffic_source.default_channel_grouping` (z ga4_sessions) | Organic, Direct, CPC, Email... |
| Country | `geo.country` | Poland, Czech Republic, Slovakia, Hungary |
| Site | na podstawie `property_id` lub `stream_id` | Wakacje.pl, TPPL, Invia CZ/SK/HU |

## Znane problemy i korekty

### 1. view_item_list — wielokrotne odpalenia na Invia
Na serwisach Invia (CZ, SK, HU) zdarzenie `view_item_list` odpala się przy każdym scroll'u listingu.
Na Wakacje.pl odpala się raz.

**Korekta:** Przy porównaniach cross-site, deduplikuj po `session_id`:
```sql
COUNT(DISTINCT IF(event_name = 'view_item_list', session_id, NULL))
```

### 2. Consent Mode — utrata danych
Różne serwisy mają różne konfiguracje consent banner:
- Wakacje.pl: ~2-5% utraty
- Invia CZ: ~15-20% utraty
- Invia HU: ~25-27% utraty

Uwzględnij to przy interpretacji absolutnych liczb.

### 3. purchaseOnClick — custom event
Nie jest standardowym eventem GA4 e-commerce. Występuje tylko na Wakacje.pl i TPPL.
Na Invia może nie być dostępny.

### 4. add_to_cart — specyfika turystyki
W branży turystycznej nie ma klasycznego koszyka.
`add_to_cart` oznacza przejście do procesu rezerwacji, nie dodanie do koszyka.

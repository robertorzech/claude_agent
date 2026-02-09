# Kontekst projektu: Web Analytics – Wakacje.pl / TPPL / Invia

## Kim jestem
Digital Analyst w zespole Web Analytics (Wakacje.pl / Grupa Wakacje).
Pracuję z GA4 → BigQuery → Looker Studio.

## Środowisko BigQuery
- Dataset GA4: ``wakacje-ga4.analytics_297373107.events_*`` (Wakacje.pl)
- Tabele: `wakacje-ga4.superform_outputs_297373107.ga4_events` (tabela po ETL dataform)

## Konwencje SQL
- Zawsze używaj backtick'ów dla nazw tabel i kolumn
- Zawsze korzystaj z tabeli `wakacje-ga4.superform_outputs_297373107.ga4_events` w której parametry eventowe/items są już rozpakowane
- Daty w formacie: `event_date BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`
- Komentarze po polsku lub angielsku (preferuję polskie)
- Stosuj CTEs zamiast podzapytań
- Każdy query powinien mieć nagłówek z opisem co robi

## Kluczowe zdarzenia e-commerce (funnel)
1. `view_item_list` – wyświetlenie listingu
2. `select_item` – kliknięcie w ofertę na listingu
3. `view_item` – wyświetlenie PO (prezentacji oferty)
4. `add_to_cart` – kliknięcie "Kup teraz"/"Zarezerwuj wstępnie"
5. `begin_checkout` – wyświetlenie I kroku ŚR
6. `add_shipping_info` – wyświetlenie II kroku ŚR
7. `purchaseOnClick` – kliknięcie "Zapłać" na IV kroku
8. `purchase` – wyświetlenie TYP (Thank You Page)

## Parsowanie kluczowych parametrów
Parametry GA4 są zakodowane w stringach item_parameter_X.
Klucze do parsowania:

### item_parameter_1 (ceny)
Format: `per:_XXXX_room:_YYYY_filter:_ZZZ_summary:_WWWW_listing_price:_VVVV`
- per: cena za osobę dorosłą
- room: cena za pokój
- filter: sposób prezentacji ceny (person/total)
- summary: cena z cross-sellami
- listing_price: cena wyświetlona na listingu

### item_parameter_22
Format: `‘pre_book:_true_duration:_12_cart_type:_shop_now’`
-‘pre_book:_czy była możliwa wstępna rezerwacja_duration:_czas trwania wstepnej rezerwacji w godzinach_cart_type:_kliknięty przycisk’

### item_parameter_5 (czas trwania i dni do wyjazdu)
Format: `d:_X_dtt:_Y_offers:_Z`
- d: czas trwania wycieczki (dni)
- dtt: dni do wyjazdu (days to trip)
- offers: liczba ofert na listingu

### item_parameter_9 (konfiguracja osobowa)
Format: `adult:_X_child:_Y`

### item_parameter_19 (cross-sell availability)
Format: `p:_X_i:_Y_pr:_Z_l:_W_s:_V`
- p: parking (0/1)
- i: ubezpieczenie (0/1)
- pr: promesa (0/1)
- l: bagaże (0/1)
- s: miejsca obok siebie (0/1)

### item_parameter_25 (wybrane cross-selle)
Format: `p:_X-NazwaP_i:_Y-NazwaU_pr:_Z_l:_W`

## Zdarzenia generyczne (non-ecommerce)
- `page_view` – odsłona strony (parametr: page_type, virtual_page)
- `plp_click` – kliknięcia na listingu (filtry, sortowanie)
- `pdp_click` – kliknięcia na PO
- `form_click` – kliknięcia w formularz na ŚR
- `form_error` – błędy formularza na ŚR
- `search` – intencyjne wyszukiwanie
- `search_section` – interakcja z wyszukiwarką
- `consent_update` – zmiana zgód RODO

## Testy AB
- Parametr: `test_name` w ab_test (np. "C_TABW131")
- Parametr `test_variant` w ab_test np. "a"

## Segmentacja
Kluczowe wymiary do segmentacji:
- device: desktop / mobile / app
- user_type: new / returning
- session_traffic_source: direct / organic / cpc / email
- page_type: homepage / listing / offer / checkout
- country: PL / CZ / SK / HU

## Ważne uwagi
- Consent mode powoduje utratę 2-27% danych w zależności od serwisu
- C1 = lead (2 krok ŚR), C2 = sprzedaż (purchase)
- C1 to liczba unikalnych użytkowników na 2 krok ŚR (add_shipping_info) do wszystkich sesji
- C2 to liczba unikalnych użytkowników na TYP (purchase) do unikalnych użytkownikow na 2 kroku ŚR (add_shipping_info)

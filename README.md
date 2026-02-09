# 🧠 Claude Agent — Web Analytics Workflow

Repozytorium do automatyzacji pracy analitycznej z BigQuery / GA4 przy pomocy Claude (Anthropic).

## Struktura

```
claude_agent/
├── CLAUDE.md                         # Główny kontekst projektu (dla Claude Code)
├── context/                          # Dokumentacja i schematy
│   ├── schema_ga4_events.md          # Schemat tabeli ga4_events (Dataform)
│   ├── parameters_reference.md       # Dokumentacja item_parameter_1 do _25
│   └── funnel_definition.md          # Definicja lejka e-commerce
├── queries/                          # Szablony SQL
│   ├── templates/                    # Uniwersalne szablony
│   ├── funnel/                       # Zapytania lejkowe
│   │   └── full_funnel_by_segment.sql
│   ├── parsing/                      # CTE do parsowania parametrów
│   │   └── parse_item_parameters.sql
│   └── ab_tests/                     # Analiza testów AB
│       └── ab_test_analysis_template.sql
├── scripts/
│   ├── ask_claude.py                 # Skrypt do wywołań Claude API
│   └── validation/
│       └── ga4_vs_crm.py             # Porównanie GA4 vs CRM
├── .github/workflows/
│   ├── claude-generate.yml           # Generowanie SQL na żądanie
│   └── weekly-funnel-report.yml      # Tygodniowy raport automatyczny
├── .claude/commands/                 # Custom slash commands dla Claude Code
│   ├── funnel.md                     # /funnel dataset_name
│   ├── ab-test.md                    # /ab-test TABW131
│   └── parse-param.md               # /parse-param 19
└── output/                           # Wyniki generowane przez Claude
```

## Setup

### 1. GitHub Secret
Dodaj `ANTHROPIC_API_KEY` w Settings → Secrets and variables → Actions.

### 2. Użycie: GitHub Actions (bez instalacji na komputerze)

**Generowanie SQL na żądanie:**
1. Idź do Actions → "🧠 Claude SQL Generator"
2. Klik "Run workflow"
3. Wpisz prompt, np. "Stwórz funnel query dla mobile z podziałem na channel"
4. Wynik pojawi się jako commit w repo

**Tygodniowy raport:**
- Odpala się automatycznie co poniedziałek o 7:00 CET
- Można też odpalić ręcznie z Actions

### 3. Użycie: Lokalne (z Claude Code)

```bash
cd claude_agent
claude  # otwiera sesję interaktywną
```

Custom commands:
```
/funnel analytics_123456
/ab-test TABW131
/parse-param 19
```

### 4. Użycie: Skrypt Python (bez Claude Code)

```bash
pip install anthropic
export ANTHROPIC_API_KEY=sk-ant-...

python scripts/ask_claude.py "Stwórz funnel query z segmentacją po device"
python scripts/ask_claude.py "Analiza testu TABW131" --output queries/ab_tests/tabw131.sql
```

## Tabele źródłowe

Dane GA4 przetwarzane przez [GA4 Dataform Package (Superform Labs)](https://github.com/robertorzech/ga4-superformlabs):
- `ga4_events` — zdarzenia (partycja: event_date, klaster: event_name, session_id)
- `ga4_sessions` — sesje z traffic source
- `ga4_transactions` — transakcje z item totals

## Kontekst biznesowy

Wakacje.pl / TPPL / Invia — branża turystyczna, rynki CEE.
- Brak klasycznego koszyka (add_to_cart = przejście do rezerwacji)
- Cross-selle: parking, ubezpieczenie, promesa, bagaże
- Ścieżka Rezerwacji (ŚR) = 4-krokowy checkout
- C1 = lead (krok 2 ŚR), C2 = sprzedaż (purchase/TYP)

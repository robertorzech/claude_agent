#!/usr/bin/env python3
"""
ga4_vs_crm.py — Porównanie danych GA4 (BigQuery) z eksportem CRM
Użycie: python scripts/validation/ga4_vs_crm.py crm_export.csv [--project PROJECT] [--dataset DATASET]

Wymaga:
  pip install google-cloud-bigquery pandas
  + Service account z dostępem do BQ (GOOGLE_APPLICATION_CREDENTIALS)
"""

import sys
import argparse
import pandas as pd
from datetime import datetime, timedelta

try:
    from google.cloud import bigquery
except ImportError:
    print("❌ Zainstaluj: pip install google-cloud-bigquery pandas")
    sys.exit(1)


def get_ga4_data(project: str, dataset: str, start_date: str, end_date: str) -> pd.DataFrame:
    """Pobierz dane purchase z BigQuery (ga4_transactions z Dataform)."""
    client = bigquery.Client(project=project)

    query = f"""
    SELECT
      transaction_date AS date,
      COUNT(DISTINCT transaction_id) AS ga4_transactions,
      SUM(ecommerce.purchase_revenue) AS ga4_revenue
    FROM `{project}.{dataset}.ga4_transactions`
    WHERE
      transaction_date BETWEEN '{start_date}' AND '{end_date}'
      AND event_name = 'purchase'
    GROUP BY transaction_date
    ORDER BY transaction_date
    """

    print(f"📊 Pobieram dane z BQ: {project}.{dataset}.ga4_transactions")
    df = client.query(query).to_dataframe()
    df['date'] = pd.to_datetime(df['date'])
    return df


def load_crm_data(filepath: str) -> pd.DataFrame:
    """Wczytaj eksport CRM z CSV."""
    print(f"📄 Wczytuję CRM: {filepath}")
    df = pd.read_csv(filepath)

    # Normalizuj nazwy kolumn
    df.columns = df.columns.str.lower().str.strip()

    # Szukaj kolumny z datą
    date_col = None
    for col in ['date', 'data', 'transaction_date', 'order_date']:
        if col in df.columns:
            date_col = col
            break

    if not date_col:
        print(f"❌ Nie znaleziono kolumny z datą. Dostępne: {list(df.columns)}")
        sys.exit(1)

    df['date'] = pd.to_datetime(df[date_col])

    # Szukaj kolumn z transakcjami i revenue
    trans_col = next((c for c in ['transactions', 'orders', 'count'] if c in df.columns), None)
    rev_col = next((c for c in ['revenue', 'total', 'amount', 'value'] if c in df.columns), None)

    result = df[['date']].copy()
    if trans_col:
        result['crm_transactions'] = pd.to_numeric(df[trans_col], errors='coerce')
    if rev_col:
        result['crm_revenue'] = pd.to_numeric(df[rev_col], errors='coerce')

    return result


def compare_data(ga4_df: pd.DataFrame, crm_df: pd.DataFrame) -> pd.DataFrame:
    """Porównaj GA4 z CRM i oblicz odchylenia."""
    merged = pd.merge(ga4_df, crm_df, on='date', how='outer').sort_values('date')

    # Odchylenia transakcji
    if 'crm_transactions' in merged.columns:
        merged['trans_diff'] = merged['ga4_transactions'] - merged['crm_transactions']
        merged['trans_diff_pct'] = (
            (merged['ga4_transactions'] - merged['crm_transactions'])
            / merged['crm_transactions'] * 100
        ).round(2)
        merged['trans_flag'] = merged['trans_diff_pct'].abs() > 10

    # Odchylenia revenue
    if 'crm_revenue' in merged.columns:
        merged['rev_diff'] = (merged['ga4_revenue'] - merged['crm_revenue']).round(2)
        merged['rev_diff_pct'] = (
            (merged['ga4_revenue'] - merged['crm_revenue'])
            / merged['crm_revenue'] * 100
        ).round(2)
        merged['rev_flag'] = merged['rev_diff_pct'].abs() > 10

    return merged


def print_summary(comparison: pd.DataFrame):
    """Wydrukuj podsumowanie porównania."""
    print("\n" + "=" * 70)
    print("📊 RAPORT: GA4 vs CRM")
    print("=" * 70)
    print(f"Okres: {comparison['date'].min().date()} – {comparison['date'].max().date()}")
    print(f"Dni w analizie: {len(comparison)}")

    if 'trans_diff_pct' in comparison.columns:
        print(f"\n🔢 TRANSAKCJE:")
        print(f"   GA4 total:  {comparison['ga4_transactions'].sum():,.0f}")
        print(f"   CRM total:  {comparison['crm_transactions'].sum():,.0f}")
        avg_diff = comparison['trans_diff_pct'].mean()
        print(f"   Śr. odchylenie: {avg_diff:+.2f}%")
        flagged = comparison[comparison['trans_flag'] == True]
        print(f"   Dni z odchyleniem >10%: {len(flagged)}")
        if len(flagged) > 0:
            print(f"   ⚠️  Problematyczne dni:")
            for _, row in flagged.iterrows():
                print(f"      {row['date'].date()}: GA4={row['ga4_transactions']:.0f}, "
                      f"CRM={row['crm_transactions']:.0f}, diff={row['trans_diff_pct']:+.1f}%")

    if 'rev_diff_pct' in comparison.columns:
        print(f"\n💰 REVENUE:")
        print(f"   GA4 total:  {comparison['ga4_revenue'].sum():,.2f}")
        print(f"   CRM total:  {comparison['crm_revenue'].sum():,.2f}")
        avg_diff = comparison['rev_diff_pct'].mean()
        print(f"   Śr. odchylenie: {avg_diff:+.2f}%")
        flagged = comparison[comparison['rev_flag'] == True]
        print(f"   Dni z odchyleniem >10%: {len(flagged)}")

    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(description="Porównanie GA4 (BQ) vs CRM")
    parser.add_argument("crm_file", help="Ścieżka do CSV z danymi CRM")
    parser.add_argument("--project", "-p", required=True, help="GCP Project ID")
    parser.add_argument("--dataset", "-d", required=True, help="BigQuery dataset")
    parser.add_argument("--start-date", help="Data początkowa (YYYY-MM-DD)")
    parser.add_argument("--end-date", help="Data końcowa (YYYY-MM-DD)")
    parser.add_argument("--output", "-o", help="Zapisz wynik do CSV")

    args = parser.parse_args()

    # Domyślne daty: ostatni miesiąc
    if not args.end_date:
        args.end_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    if not args.start_date:
        args.start_date = (datetime.now() - timedelta(days=31)).strftime('%Y-%m-%d')

    # Pobierz dane
    ga4_df = get_ga4_data(args.project, args.dataset, args.start_date, args.end_date)
    crm_df = load_crm_data(args.crm_file)

    # Porównaj
    comparison = compare_data(ga4_df, crm_df)

    # Wydrukuj podsumowanie
    print_summary(comparison)

    # Zapisz CSV
    if args.output:
        comparison.to_csv(args.output, index=False)
        print(f"\n✅ Raport zapisany: {args.output}")
    else:
        default_output = f"output/ga4_vs_crm_{args.start_date}_{args.end_date}.csv"
        comparison.to_csv(default_output, index=False)
        print(f"\n✅ Raport zapisany: {default_output}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
ask_claude.py — Skrypt do generowania SQL/analiz z pomocą Claude API
Użycie: python scripts/ask_claude.py "Twój prompt" [--output plik.sql] [--context plik1.md plik2.md]

Przykłady:
  python scripts/ask_claude.py "Stwórz funnel query z segmentacją po device"
  python scripts/ask_claude.py "Przeanalizuj parametry cross-sell" --output queries/cross_sell.sql
  python scripts/ask_claude.py "Stwórz raport consent mode" --context context/schema_ga4_events.md
"""

import os
import sys
import argparse
import glob
from pathlib import Path

try:
    import anthropic
except ImportError:
    print("❌ Brak biblioteki anthropic. Zainstaluj: pip install anthropic")
    sys.exit(1)


def load_context_files(context_dir: str = "context", extra_files: list = None) -> str:
    """Wczytaj pliki kontekstowe z folderu context/ + CLAUDE.md"""
    context_parts = []

    # 1. CLAUDE.md (główny plik kontekstu)
    claude_md = Path("CLAUDE.md")
    if claude_md.exists():
        context_parts.append(f"=== CLAUDE.md ===\n{claude_md.read_text()}\n")

    # 2. Pliki z folderu context/
    context_path = Path(context_dir)
    if context_path.exists():
        for file in sorted(context_path.glob("*.md")):
            context_parts.append(f"=== {file.name} ===\n{file.read_text()}\n")
        for file in sorted(context_path.glob("*.sql")):
            context_parts.append(f"=== {file.name} ===\n{file.read_text()}\n")

    # 3. Dodatkowe pliki podane explicite
    if extra_files:
        for filepath in extra_files:
            p = Path(filepath)
            if p.exists():
                context_parts.append(f"=== {p.name} ===\n{p.read_text()}\n")
            else:
                print(f"⚠️  Plik nie znaleziony: {filepath}")

    return "\n".join(context_parts)


def ask_claude(prompt: str, context: str, model: str = "claude-sonnet-4-20250514") -> str:
    """Wyślij zapytanie do Claude API z kontekstem projektu."""
    client = anthropic.Anthropic()  # automatycznie czyta ANTHROPIC_API_KEY z env

    system_prompt = f"""Jesteś ekspertem BigQuery, GA4 i web analytics. 
Pracujesz jako asystent Digital Analityka w Wakacje.pl (branża turystyczna, rynki CEE).
Dane GA4 są przetwarzane przez GA4 Dataform Package (Superform Labs) — tabele są już unnestowane.

Oto kontekst projektu:

{context}

Zasady:
1. Generuj SQL kompatybilny z BigQuery (Standard SQL)
2. Używaj CTE zamiast podzapytań
3. Dodawaj komentarze po polsku
4. Używaj SAFE_CAST i SAFE_DIVIDE dla bezpieczeństwa
5. Parametryzuj daty jako @start_date / @end_date
6. Odwołuj się do tabel z Dataform: ga4_events, ga4_sessions, ga4_transactions
7. Pamiętaj o specyfice branży turystycznej (brak koszyka, cross-selle, ŚR)
"""

    response = client.messages.create(
        model=model,
        max_tokens=4096,
        system=system_prompt,
        messages=[{"role": "user", "content": prompt}]
    )

    return response.content[0].text


def main():
    parser = argparse.ArgumentParser(
        description="Generuj SQL/analizy z pomocą Claude API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Przykłady:
  %(prog)s "Stwórz funnel query z segmentacją po device"
  %(prog)s "Analiza AB testu TABW131" --output queries/ab_tests/tabw131.sql
  %(prog)s "Raport consent mode" --context context/consent_mode_notes.md
  %(prog)s "Porównaj Wakacje.pl vs TPPL" --model claude-opus-4-6
        """
    )
    parser.add_argument("prompt", help="Prompt / pytanie do Claude")
    parser.add_argument("--output", "-o", help="Zapisz wynik do pliku")
    parser.add_argument("--context", "-c", nargs="*", help="Dodatkowe pliki kontekstowe")
    parser.add_argument("--model", "-m", default="claude-sonnet-4-20250514",
                        help="Model Claude (default: claude-sonnet-4-20250514)")
    parser.add_argument("--context-dir", default="context",
                        help="Folder z plikami kontekstowymi (default: context/)")
    parser.add_argument("--quiet", "-q", action="store_true",
                        help="Wypisz tylko wynik (bez logów)")

    args = parser.parse_args()

    # Sprawdź API key
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("❌ Brak ANTHROPIC_API_KEY. Ustaw jako zmienną środowiskową.")
        print("   export ANTHROPIC_API_KEY=sk-ant-...")
        print("   Lub dodaj w GitHub Secrets jako ANTHROPIC_API_KEY")
        sys.exit(1)

    if not args.quiet:
        print(f"📂 Ładuję kontekst z {args.context_dir}/...")

    context = load_context_files(args.context_dir, args.context)

    if not args.quiet:
        print(f"🧠 Model: {args.model}")
        print(f"💬 Prompt: {args.prompt[:100]}...")
        print("⏳ Generuję odpowiedź...\n")

    result = ask_claude(args.prompt, context, args.model)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(result)
        if not args.quiet:
            print(f"✅ Zapisano do: {args.output}")
    else:
        print(result)


if __name__ == "__main__":
    main()

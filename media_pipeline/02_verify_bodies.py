#!/usr/bin/env python3
"""
02_verify_bodies.py
=========================

For each flagged article URL in Mini_Forest_titles_classified.xlsx,
fetch the page and assess whether the article is actually about Mini Forests.

EXTRACTION PIPELINE (each URL):
    1. trafilatura.extract(favor_recall=True)           — primary clean-body parser
    2. readability-lxml.Document — fallback if (1) returned <500 chars or no Miyawaki match
    3. BeautifulSoup raw-text     — final fallback after stripping nav/footer/script/style
    4. Raw-HTML keyword scan       — runs on every URL regardless of extraction success,
                                     to catch articles where extraction is incomplete

VERDICT RULES (lede-plus-count, with raw-HTML safety net):
    'About_Miyawaki'              — 'miyawaki' (any script) appears in title OR first 2
                                    paragraphs of extracted body, OR appears 3+ times
                                    anywhere in the extracted body
    'Passing_Mention'             — appears 1-2 times deeper in extracted body
    'Likely_About_Miyawaki_RawHTML' — extracted body has 0 mentions, but raw HTML has 1+
                                    (extraction probably truncated; needs eyeball check)
    'No_Mention'                  — not present in extracted body OR raw HTML
    'Fetch_Failed'                — could not retrieve the page
    'Extract_Failed'              — page loaded but every extractor returned nothing

Writes results to the 'Body_verified' sheet in the same workbook. Re-running skips
already-verified URLs (resume on URL key).

USAGE
-----
    pip install --user requests trafilatura readability-lxml beautifulsoup4 \
                       pandas openpyxl tqdm lxml_html_clean
    python3 02_verify_bodies.py

Optional flags:
    --xlsx PATH         Workbook to read/write (default: this folder's classified file)
    --limit N           Stop after N URLs (useful for testing)
    --delay S           Mean delay between requests in seconds (default: 1.5)
    --timeout S         Per-request timeout in seconds (default: 20)
    --only TYPES        Comma-separated classifications to verify
                        (default: Not_Miyawaki,Review_UrbanForest,Review_Afforestation,
                                  Review_Reforestation,Review_GreenCover)
    --reverify VERDICTS Comma-separated verdicts to re-fetch from prior runs.
                        Example: --reverify Fetch_Failed,Extract_Failed,No_Mention
                        Those rows are dropped from Body_verified and re-processed
                        with the current extraction pipeline. Useful after upgrading
                        the parser. Default: empty (resume-only).

NOTES
-----
- The script is polite: a randomized delay between requests, a desktop User-Agent,
  and a single retry on timeouts. Total runtime for ~1,140 URLs at default delay
  is roughly 30-45 minutes.
- The 'extraction_method' column records which parser produced the body text used
  for the verdict (trafilatura | readability | bs4 | none). Use it to audit which
  outlets need a different approach.
- The 'raw_html_mention_count' column lets you spot articles where extraction
  truncated content: a positive raw-HTML count combined with a body count of zero
  indicates the extractor missed the relevant section.
"""

from __future__ import annotations

import argparse
import logging
import random
import re
import sys
import time
import unicodedata
from pathlib import Path

# Lazy imports so missing deps produce a clear message.
try:
    import pandas as pd
    import requests
    import trafilatura
    from bs4 import BeautifulSoup
    from readability import Document as ReadabilityDocument
    from openpyxl import load_workbook
    from openpyxl.styles import Font, PatternFill
    from tqdm import tqdm
except ImportError as e:
    print(
        f"\nMissing dependency: {e.name}\n\n"
        "Install with:\n"
        "    pip install --user requests trafilatura readability-lxml beautifulsoup4 \\\n"
        "                       pandas openpyxl tqdm lxml_html_clean\n"
    )
    sys.exit(1)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_XLSX = (
    Path(__file__).resolve().parent.parent
    / "data"
    / "Mini_Forest_merged_media_corpus.xlsx"
)

# Try this sheet first; fall back to "All_classified" for v1/v2 schema compatibility
DEFAULT_SHEET_PRIORITY = ("Merged_corpus", "All_classified")

DEFAULT_TYPES = (
    "Not_Miyawaki,Review_UrbanForest,Review_Afforestation,"
    "Review_Reforestation,Review_GreenCover"
)

# Match Miyawaki in Latin and the common non-Latin scripts that appeared in the source data.
MIYAWAKI_PATTERNS = [
    re.compile(r"miyawaki", re.IGNORECASE),  # Latin
    re.compile(r"宮脇"),                      # Chinese / Japanese kanji
    re.compile(r"ミヤワキ"),                   # Japanese katakana
    re.compile(r"मियावाकी"),                  # Hindi
]

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)


# ---------------------------------------------------------------------------
# Article fetch + extract
# ---------------------------------------------------------------------------


def fetch_html(url: str, timeout: int) -> tuple[str | None, str]:
    """Return (html_text, status_code_or_error). On failure, html_text is None."""
    headers = {
        "User-Agent": USER_AGENT,
        "Accept-Language": "en-US,en;q=0.8",
    }
    try:
        r = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
        if r.status_code >= 400:
            return None, f"HTTP {r.status_code}"
        # Some outlets return tiny paywall pages; trafilatura handles emptiness downstream.
        return r.text, f"HTTP {r.status_code}"
    except requests.exceptions.Timeout:
        return None, "timeout"
    except requests.exceptions.RequestException as e:
        return None, f"request_error:{type(e).__name__}"


_MIN_BODY_CHARS = 500   # below this, try the next extractor


def _trafilatura_extract(html: str, url: str) -> str | None:
    try:
        return trafilatura.extract(
            html,
            url=url,
            include_comments=False,
            include_tables=False,
            no_fallback=False,
            favor_recall=True,
        )
    except Exception:
        return None


def _readability_extract(html: str) -> str | None:
    """Use readability-lxml as a fallback. Returns plain text of the article DIV."""
    try:
        doc = ReadabilityDocument(html)
        summary_html = doc.summary(html_partial=True)
        soup = BeautifulSoup(summary_html, "lxml")
        # readability gives us <div><p>...</p>...</div>; preserve paragraph breaks
        paras = [p.get_text(" ", strip=True) for p in soup.find_all(["p", "h1", "h2", "h3", "li"])]
        text = "\n".join(p for p in paras if p)
        return text or None
    except Exception:
        return None


def _bs4_fallback_extract(html: str) -> str | None:
    """Last-resort extractor: strip nav/footer/script/style and return whatever <p> text remains."""
    try:
        soup = BeautifulSoup(html, "lxml")
        for tag in soup(["script", "style", "nav", "footer", "header", "aside", "form", "noscript"]):
            tag.decompose()
        # Prefer <article> or <main> if present
        target = soup.find("article") or soup.find("main") or soup.body or soup
        paras = [p.get_text(" ", strip=True) for p in target.find_all(["p", "h1", "h2", "h3", "li"])]
        text = "\n".join(p for p in paras if p)
        return text or None
    except Exception:
        return None


def _raw_html_to_visible_text(html: str) -> str:
    """Strip tags, scripts, styles to produce a plain-text representation of the page —
    used purely for keyword detection (not for verdict body)."""
    try:
        soup = BeautifulSoup(html, "lxml")
        for tag in soup(["script", "style", "noscript"]):
            tag.decompose()
        return soup.get_text(" ", strip=True)
    except Exception:
        # Fall back to crude regex-based stripping
        text = re.sub(r"<script.*?</script>", " ", html, flags=re.S | re.I)
        text = re.sub(r"<style.*?</style>", " ", text, flags=re.S | re.I)
        text = re.sub(r"<[^>]+>", " ", text)
        return text


def extract_body(html: str, url: str) -> tuple[str | None, str]:
    """
    Try trafilatura → readability-lxml → BeautifulSoup, returning the first body that
    is both non-empty AND either >=MIN_BODY_CHARS chars or contains a Miyawaki mention.

    Returns (best_body, method_label).
    """
    if not html:
        return None, "none"

    # Stage 1: trafilatura
    body = _trafilatura_extract(html, url)
    if body and (len(body) >= _MIN_BODY_CHARS or count_mentions(body)[0] > 0):
        return body, "trafilatura"

    # Stage 2: readability
    body2 = _readability_extract(html)
    if body2 and (len(body2) >= _MIN_BODY_CHARS or count_mentions(body2)[0] > 0):
        return body2, "readability"

    # Stage 3: bs4 raw
    body3 = _bs4_fallback_extract(html)
    if body3 and (len(body3) >= _MIN_BODY_CHARS or count_mentions(body3)[0] > 0):
        return body3, "bs4"

    # Nothing great — return the longest candidate we got, just so we don't lose all info
    candidates = [(body, "trafilatura"), (body2, "readability"), (body3, "bs4")]
    candidates = [(t, m) for t, m in candidates if t]
    if not candidates:
        return None, "none"
    candidates.sort(key=lambda tm: len(tm[0]), reverse=True)
    return candidates[0]


# ---------------------------------------------------------------------------
# Detection logic
# ---------------------------------------------------------------------------


def count_mentions(text: str) -> tuple[int, list[str]]:
    """Return (count, list of ~120-char excerpts surrounding each mention)."""
    if not text:
        return 0, []
    excerpts: list[str] = []
    n = 0
    for pat in MIYAWAKI_PATTERNS:
        for m in pat.finditer(text):
            n += 1
            start = max(0, m.start() - 60)
            end = min(len(text), m.end() + 60)
            excerpt = text[start:end].replace("\n", " ").strip()
            excerpts.append(excerpt)
    return n, excerpts


def lede_text(body: str, paragraphs: int = 2) -> str:
    """Return the first N non-empty paragraphs as a single string."""
    if not body:
        return ""
    parts = [p.strip() for p in body.split("\n") if p.strip()]
    return " ".join(parts[:paragraphs])


def classify_verdict(
    title: str, body: str, raw_html_text: str
) -> tuple[str, int, bool, list[str], int]:
    """
    Return (verdict, body_mention_count, in_lede, excerpts, raw_html_mention_count).

    The raw_html safety net catches cases where extraction truncated the article body
    but the raw-HTML page text contains 'Miyawaki' — those are flagged as
    'Likely_About_Miyawaki_RawHTML' for manual review.
    """
    body = body or ""
    title = title or ""
    raw_html_text = raw_html_text or ""

    body_n, excerpts = count_mentions(body)
    title_n, _ = count_mentions(title)
    lede_n, _ = count_mentions(lede_text(body, paragraphs=2))
    raw_n, raw_excerpts = count_mentions(raw_html_text)
    in_lede = (title_n > 0) or (lede_n > 0)

    # Total failure: nothing extracted, no title hit, nothing in raw HTML
    if not body and title_n == 0 and raw_n == 0:
        return "Extract_Failed", 0, False, [], 0

    # Strong positives based on extracted body
    if in_lede:
        return "About_Miyawaki", body_n, True, excerpts[:5], raw_n
    if body_n >= 3:
        return "About_Miyawaki", body_n, False, excerpts[:5], raw_n
    if 1 <= body_n <= 2:
        return "Passing_Mention", body_n, False, excerpts[:5], raw_n

    # Body says nothing — but raw HTML does. Flag for manual eyeball.
    if raw_n > 0:
        return "Likely_About_Miyawaki_RawHTML", 0, False, raw_excerpts[:5], raw_n

    return "No_Mention", 0, False, [], 0


# ---------------------------------------------------------------------------
# Workbook I/O
# ---------------------------------------------------------------------------

OUTPUT_COLUMNS = [
    "publish_date",
    "language",
    "media_name",
    "title",
    "url",
    "classification",
    "fetch_status",
    "verdict",
    "body_mention_count",
    "raw_html_mention_count",
    "in_lede",
    "extraction_method",
    "extracted_chars",
    "miyawaki_excerpts",
]


def load_existing_results(xlsx: Path) -> pd.DataFrame:
    if not xlsx.exists():
        raise SystemExit(f"Workbook not found: {xlsx}")
    wb = load_workbook(xlsx, read_only=True, data_only=True)
    if "Body_verified" not in wb.sheetnames:
        return pd.DataFrame(columns=OUTPUT_COLUMNS)
    df = pd.read_excel(xlsx, sheet_name="Body_verified")
    return df


def save_results(xlsx: Path, results: pd.DataFrame) -> None:
    """Write results to the 'Body_verified' sheet, preserving other sheets."""
    wb = load_workbook(xlsx)
    if "Body_verified" in wb.sheetnames:
        del wb["Body_verified"]
    ws = wb.create_sheet("Body_verified")
    headers = list(results.columns)
    ws.append(headers)
    for cell in ws[1]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor="DDDDDD")
    for _, row in results.iterrows():
        ws.append([row.get(c, "") if pd.notna(row.get(c, "")) else "" for c in headers])

    # color rows by verdict
    palette = {
        "About_Miyawaki":                  "C6EFCE",  # green
        "Likely_About_Miyawaki_RawHTML":   "B4D7E7",  # blue (needs eyeball check)
        "Passing_Mention":                 "FFEB9C",  # amber
        "No_Mention":                      "FFC7CE",  # red
        "Fetch_Failed":                    "D9D9D9",  # grey
        "Extract_Failed":                  "D9D9D9",  # grey
    }
    verdict_col = headers.index("verdict") + 1
    for r in range(2, ws.max_row + 1):
        v = ws.cell(row=r, column=verdict_col).value
        hexc = palette.get(v)
        if hexc:
            fill = PatternFill("solid", fgColor=hexc)
            for c in range(1, len(headers) + 1):
                ws.cell(row=r, column=c).fill = fill

    widths = [12, 6, 22, 60, 50, 22, 14, 22, 14, 18, 8, 16, 12, 90]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[chr(64 + i)].width = w
    ws.freeze_panes = "A2"

    wb.save(xlsx)


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--xlsx", type=Path, default=DEFAULT_XLSX, help="Workbook to read/write")
    ap.add_argument("--limit", type=int, default=0, help="Stop after N URLs (0 = no limit)")
    ap.add_argument("--delay", type=float, default=1.5, help="Mean delay between fetches (seconds)")
    ap.add_argument("--timeout", type=int, default=20, help="Per-request timeout (seconds)")
    ap.add_argument("--only", type=str, default=DEFAULT_TYPES, help="Classifications to verify")
    ap.add_argument("--save-every", type=int, default=25, help="Persist results every N URLs")
    ap.add_argument(
        "--reverify",
        type=str,
        default="",
        help="Comma-separated verdicts to drop from prior results and re-fetch "
             "(e.g. 'Fetch_Failed,Extract_Failed,No_Mention'). Default: empty (resume only).",
    )
    ap.add_argument(
        "--sheet",
        type=str,
        default="",
        help=f"Sheet name to read worklist from. Default: try {list(DEFAULT_SHEET_PRIORITY)} in order.",
    )
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )
    log = logging.getLogger("verify")

    if not args.xlsx.exists():
        log.error("Workbook not found: %s", args.xlsx)
        return 1

    target_classes = [s.strip() for s in args.only.split(",") if s.strip()]

    # Load source data — pick the right sheet for this workbook (Merged_corpus or All_classified)
    available = pd.ExcelFile(args.xlsx).sheet_names
    if args.sheet:
        if args.sheet not in available:
            log.error("Requested sheet %r not in workbook. Available: %s", args.sheet, available)
            return 1
        sheet = args.sheet
    else:
        sheet = next((s for s in DEFAULT_SHEET_PRIORITY if s in available), None)
        if sheet is None:
            log.error("None of the default sheets %s are in workbook. Use --sheet to specify. Available: %s",
                      list(DEFAULT_SHEET_PRIORITY), available)
            return 1
    log.info("Reading worklist from sheet: %r", sheet)

    df_all = pd.read_excel(args.xlsx, sheet_name=sheet)
    # Skip ProQuest-only rows — those URLs are BU ezproxy-protected and not fetchable
    if "source" in df_all.columns:
        before = len(df_all)
        df_all = df_all[df_all["source"] != "ProQuest"].copy()
        log.info("Filtered out %d ProQuest-only rows (ezproxy URLs are not fetchable)", before - len(df_all))
    worklist = df_all[df_all["classification"].isin(target_classes)].copy().reset_index(drop=True)
    log.info("Loaded %d rows in target classifications", len(worklist))

    # Load any prior results to resume — dedup on URL, since id is not in All_classified
    prior = load_existing_results(args.xlsx)

    # If --reverify is set, drop matching rows from prior so they get re-fetched
    reverify_list = [s.strip() for s in args.reverify.split(",") if s.strip()]
    if reverify_list and len(prior):
        before = len(prior)
        prior = prior[~prior["verdict"].astype(str).isin(reverify_list)].copy()
        log.info("--reverify: dropped %d prior rows (%s) for re-fetch",
                 before - len(prior), reverify_list)

    done_urls: set[str] = set(prior["url"].astype(str).tolist()) if len(prior) else set()
    log.info("Resuming with %d already-verified rows", len(done_urls))

    # Filter to remaining
    remaining = worklist[~worklist["url"].astype(str).isin(done_urls)].reset_index(drop=True)
    if args.limit > 0:
        remaining = remaining.head(args.limit)
    log.info("To fetch: %d", len(remaining))

    new_rows: list[dict] = []
    saved_n = 0
    pbar = tqdm(remaining.itertuples(index=False), total=len(remaining), unit="url")
    for row in pbar:
        url = row.url
        title = row.title
        pbar.set_description(url[:60])

        html, status = fetch_html(url, timeout=args.timeout)
        if html is None and status == "timeout":
            time.sleep(2.0)
            html, status = fetch_html(url, timeout=args.timeout)

        if html is None:
            new_rows.append({
                "publish_date": row.publish_date,
                "language": row.language,
                "media_name": row.media_name,
                "title": title,
                "url": url,
                "classification": row.classification,
                "fetch_status": status,
                "verdict": "Fetch_Failed",
                "body_mention_count": "",
                "raw_html_mention_count": "",
                "in_lede": "",
                "extraction_method": "none",
                "extracted_chars": 0,
                "miyawaki_excerpts": "",
            })
        else:
            body, method = extract_body(html, url)
            raw_text = _raw_html_to_visible_text(html)
            verdict, n, in_lede, excerpts, raw_n = classify_verdict(title, body or "", raw_text)
            new_rows.append({
                "publish_date": row.publish_date,
                "language": row.language,
                "media_name": row.media_name,
                "title": title,
                "url": url,
                "classification": row.classification,
                "fetch_status": status,
                "verdict": verdict,
                "body_mention_count": n,
                "raw_html_mention_count": raw_n,
                "in_lede": "yes" if in_lede else "no",
                "extraction_method": method,
                "extracted_chars": len(body) if body else 0,
                "miyawaki_excerpts": " | ".join(excerpts) if excerpts else "",
            })

        # politeness: jittered delay around the requested mean
        time.sleep(max(0.2, random.uniform(args.delay * 0.5, args.delay * 1.5)))

        # incremental save so a Ctrl-C doesn't lose progress
        saved_n += 1
        if saved_n % args.save_every == 0:
            combined = pd.concat([prior, pd.DataFrame(new_rows)], ignore_index=True)
            save_results(args.xlsx, combined)
            log.info("Saved checkpoint: %d total rows", len(combined))

    # Final save
    combined = pd.concat([prior, pd.DataFrame(new_rows)], ignore_index=True)
    save_results(args.xlsx, combined)

    # Summary
    print()
    print("=== Summary ===")
    print(combined["verdict"].value_counts().to_string())
    print(f"\nTotal verified rows: {len(combined)}")
    print(f"Saved to: {args.xlsx}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Media Step 4 — cross-database merge + deduplication.
=====================================================================
MATCH RULE (a MediaCloud row and a ProQuest row are the same article if):
    canonical_outlet equal  AND  |publish_date difference| <= 1 day
    AND  Jaccard token overlap on normalized titles >= 0.70

VALIDATION:
  (1) Jaccard function vs. the 30 stored pairs in the `Dedup_audit_sample` sheet:
        28 / 30 reproduced exactly (±0.005); 2 differ by a single-token
        normalization edge (stopword / hyphen) — confirms the metric.
  (2) Full end-to-end reproduction from the 4 ProQuest Miyawaki chunks + the
        2,328 English MediaCloud rows:
            reproduced matches .... 683     (recorded 'both' = 628)
            MediaCloud-only ....... 1,645   (recorded 1,700)
            ProQuest-only ......... 2,692   (recorded 2,747)
            merged total .......... 5,020   (recorded 5,075)   <- within ~1%
        Matches concentrate in the same outlets the record shows
        (Times of India, The Hindu, Hindustan Times, Guardian, Straits Times).
        The ~9% over-count vs. 628 reflects marginally more permissive title
        normalization than the original and the absence of the original ~50-outlet
        canonical-alias crosswalk (not preserved). Exact reproduction would require
        that crosswalk and the original token-normalization rules.
"""
import re
import glob
from collections import defaultdict
import pandas as pd

# Canonical-outlet aliases for the cross-domain equivalents that actually overlap.
# (The original used a ~50-outlet crosswalk; only these produced Miyawaki matches.)
ALIAS = {
    "indiatimes": "times_of_india", "timesofindia": "times_of_india",
    "thehindu": "hindu", "hindu": "hindu",
    "hindustantimes": "hindustan_times",
    "theguardian": "guardian", "guardian": "guardian",
    "straitstimes": "straits_times",
    "indianexpress": "indian_express", "newindianexpress": "indian_express",
}


def canon_outlet(name):
    s = str(name).lower()
    s = re.sub(r"\(online\)", "", s)
    s = re.sub(r"https?://|www\.", "", s)
    s = re.sub(r"\.(com|in|org|net|co\.uk|co\.in|pk)\b", "", s)
    s = re.sub(r"^the\s+", "", s)
    s = re.sub(r"[^a-z0-9]", "", s)
    return ALIAS.get(s, s)


def _tokens(s):
    s = re.sub(r"[^a-z0-9\s]", " ", str(s).lower())
    return set(t for t in s.split() if t)


def jaccard(a, b):
    A, B = _tokens(a), _tokens(b)
    return len(A & B) / len(A | B) if A and B else 0.0


def merge(mc_df, pq_df, date_window=1, threshold=0.70, return_frame=False):
    """Return (n_matched, mc_only, pq_only). mc_df needs columns
    [title, date_iso, media_name]; pq_df needs [Title, pubdate, pubtitle, language].

    With return_frame=True also returns the MediaCloud frame tagged with a `source`
    column ("both" where a ProQuest match was found, else "MediaCloud") and the
    filtered ProQuest frame, so the merged corpus can be written out."""
    mc = mc_df.copy()
    mc["cdate"] = pd.to_datetime(mc["date_iso"], errors="coerce")
    mc["coutlet"] = mc["media_name"].map(canon_outlet)

    pq = pq_df.copy()
    pq["cdate"] = pd.to_datetime(pq["pubdate"], errors="coerce")
    pq = pq[(pq["cdate"] >= pd.Timestamp("2015-01-01")) & (pq["cdate"] <= pd.Timestamp("2025-12-31"))]
    pq = pq[pq["language"].astype(str).str.lower().str.contains("english")]
    pq["coutlet"] = pq["pubtitle"].map(canon_outlet)

    pq_by = defaultdict(list)
    for r in pq.itertuples():
        pq_by[r.coutlet].append((r.cdate, r.Title))

    # single matching pass; `hit` records, per MediaCloud row, whether a ProQuest
    # record satisfied all three conditions (outlet, date window, Jaccard).
    hit = []
    for r in mc.itertuples():
        found = False
        if not pd.isna(r.cdate):
            for pdate, ptitle in pq_by.get(r.coutlet, []):
                if pd.notna(pdate) and abs((r.cdate - pdate).days) <= date_window and jaccard(r.title, ptitle) >= threshold:
                    found = True
                    break
        hit.append(found)
    matched = sum(hit)
    if return_frame:
        mc = mc.assign(source=["both" if h else "MediaCloud" for h in hit])
        return (matched, len(mc) - matched, len(pq) - matched), mc, pq
    return matched, len(mc) - matched, len(pq) - matched


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Media Step 4 - cross-database merge + deduplication.")
    ap.add_argument("xlsx", help="corpus workbook (MediaCloud rows)")
    ap.add_argument("proquest_glob", help="glob for the raw ProQuest .xls exports")
    ap.add_argument("--sheet", default="Merged_corpus", help="sheet to read (default: Merged_corpus)")
    ap.add_argument("--out", help="write the merged corpus to this .xlsx")
    a = ap.parse_args()

    m = pd.read_excel(a.xlsx, sheet_name=a.sheet)
    mc = m[m["source"].isin(["MediaCloud", "both"])]
    pq = pd.concat([pd.read_excel(f) for f in sorted(glob.glob(a.proquest_glob))], ignore_index=True)

    if a.out:
        (n, mc_only, pq_only), mc_tagged, pq_kept = merge(mc, pq, return_frame=True)
        pq_kept = pq_kept.assign(source="ProQuest")
        merged = pd.concat([mc_tagged, pq_kept], ignore_index=True)
        merged.to_excel(a.out, sheet_name="Merged_corpus", index=False)
        print("wrote %s  (%d rows)" % (a.out, len(merged)))
    else:
        n, mc_only, pq_only = merge(mc, pq)
    print("matches=%d  mc_only=%d  pq_only=%d  total=%d" % (n, mc_only, pq_only, n + mc_only + pq_only))

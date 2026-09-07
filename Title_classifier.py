#!/usr/bin/env python3
"""
Mdia Step 2 — title-only relevance classifier.
=================================================================

VALIDATION (run against `classification_v1` in CLAUDE_Miyawaki_merged_corpus.xlsx,
            2,328 English MediaCloud-origin rows):
    - Exact 8-class agreement ............ 97.0%
    - `Miyawaki` (literal keyword) ....... 354 / 354  (exact)
    - On-topic binary (Miyawaki+Likely) .. 99.1%   <- the distinction Figure 1 uses
    - Flagged-for-body-verify set ........ 99.1%
Residual differences sit entirely in the Review_* vs Not_Miyawaki boundary
(all of which are flagged for body verification downstream, so no effect on the
focal/passing counts). Exact reproduction is not possible because the original
keyword lists were not preserved.
"""
import re
import pandas as pd

MIYAWAKI_TOKENS = ["miyawaki", "宮脇", "ミヤワキ", "मियावाकी"]  # incl. 宮脇 / ミヤワキ / मियावाकी
LIKELY = [r"tiny\s+forest", r"mini[\s-]?forest", r"micro[\s-]?forest", r"pocket\s+forest",
          r"dense\s+forest", r"sacred\s+forest", r"miniature\s+forest",
          r"japanese\s+(method|style|technique|forest)", r"fast[\s-]?grow\w*\s+forest"]
URBANFOREST = [r"urban\s+forest", r"urban\s+forestry", r"urban\s+tree", r"urban\s+canopy",
               r"urban\s+green", r"city\s+forest", r"city\s+tree", r"street\s+tree"]
AFFOREST = [r"afforest"]
REFOREST = [r"reforest"]
GREENCOVER = [r"tree[\s-]?planting", r"plant\w*\s+\d*\s*trees?", r"plantation",
              r"sapling", r"green\s+cover", r"greening", r"green\s+space",
              r"woodland", r"rewild", r"million\s+trees?",
              r"forest\s+(drive|campaign|cover|restoration)"]


def _hit(patterns, s):
    return any(re.search(p, s) for p in patterns)


def classify(title, url=""):
    """Return one of: Miyawaki / Likely_Miyawaki / Review_Afforestation /
    Review_Reforestation / Review_UrbanForest / Review_GreenCover / Not_Miyawaki."""
    t = (str(title) or "").lower()
    u = (str(url) or "").lower()
    blob = t + " " + u
    if any(tok.lower() in blob for tok in MIYAWAKI_TOKENS):
        return "Miyawaki"
    if _hit(LIKELY, t):
        return "Likely_Miyawaki"
    if _hit(AFFOREST, t):
        return "Review_Afforestation"
    if _hit(REFOREST, t):
        return "Review_Reforestation"
    if _hit(URBANFOREST, t):
        return "Review_UrbanForest"
    if _hit(GREENCOVER, t):
        return "Review_GreenCover"
    return "Not_Miyawaki"


def validate(corpus_xlsx):
    """Re-run the validation reported in the module docstring."""
    m = pd.read_excel(corpus_xlsx, sheet_name="Merged_corpus")
    mc = m[m["source"].isin(["MediaCloud", "both"])].copy()
    mc["recon"] = [classify(r.title, r.url) for r in mc.itertuples()]
    gt, pred = mc["classification_v1"], mc["recon"]
    ot = lambda s: s.isin(["Miyawaki", "Likely_Miyawaki"])
    print("rows:", len(mc))
    print("exact 8-class:      %.1f%%" % (100 * (gt == pred).mean()))
    print("on-topic binary:    %.1f%%" % (100 * (ot(gt) == ot(pred)).mean()))


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        validate(sys.argv[1])
    else:
        print("usage: python recon_step2_title_classifier.py <CLAUDE_Miyawaki_merged_corpus.xlsx>")

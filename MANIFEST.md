# Input / output map

Paths are relative to the repository root; run the scripts from the repository root.
Scripts under `costs/` use paths relative to `costs/`.

## Data included

| File | Sheets the scripts read |
|---|---|
| `data/Mini_Forest_academic_corpus.xlsx` | `Paper_analysis` — 108 studies × 31 columns |
| `data/Mini_Forest_merged_media_corpus.xlsx` | `Merged_corpus` (5,075 records), `Body_verified` (1,340), `Dedup_audit_sample` |
| `data/Mini_Forest_titles_classified.xlsx` | `All_classified` (2,480), `Flagged_NotMiyawaki` (1,900), `Body_verified` |
| `costs/data/planting_costs.csv` | one row per planting, with a per-row `source` column |

**Not redistributed** (public but too large, or licence-restricted): `TCUSA_Data2016_2025.xlsx`
(Arbor Day Foundation), `EDGE_LOCALE25_US.*` (NCES), `tl_2025_{ss}_{cousub,place}.*`
(Census TIGER/Line, FIPS 09/23/25/33/34/36/42/44/50), and the raw MediaCloud and ProQuest
search exports. Retrieval instructions are in `costs/README.md`.

## R — figures and tables

| Script | Reads | Writes |
|---|---|---|
| `figures_and_tables/01_Fig1_media_vs_research.R` | `data/Mini_Forest_academic_corpus.xlsx` (`Paper_analysis`)<br>`data/Mini_Forest_merged_media_corpus.xlsx` (`Merged_corpus`) | `Figure1_mini_forest_media_vs_research_2015-2025.{pdf,png,svg}` |
| `figures_and_tables/02_Fig2_evidence_matrix.R` | `data/Mini_Forest_academic_corpus.xlsx` (`Paper_analysis`) | `Figure2_Mini_Forest_evidence_matrix.{pdf,png,svg}`<br>`Figure2_service_assignments.csv` |
| `figures_and_tables/03_TableS1_evidence_text.R` | `Figure2_service_assignments.csv` | `TableS1_condensed_vs_verbatim.csv` |
| `figures_and_tables/04_FigS1_combined_evidence.R` | `data/Mini_Forest_academic_corpus.xlsx` (`Paper_analysis`) | `Mini_Forest_combined_evidence_figure.{pdf,svg,png}`<br>`FigureS1_Mini_Forest_combined_evidence_figure.{pdf,svg,png}` |

**Order:** run `Figure2_evidence_matrix.R` before `TableS1_evidence_text.R` —
`Figure2_service_assignments.csv` is the handoff. The other two are independent.

## Python — media pipeline (Steps 2–4)

| Script | Reads | Writes |
|---|---|---|
| `media_pipeline/01_title_classifier.py` | `data/Mini_Forest_merged_media_corpus.xlsx` (`Merged_corpus`) | with `--out FILE.xlsx`: an `All_classified` sheet with a `classification` column.<br>Without `--out`: prints agreement against the stored `classification_v1`. |
| `media_pipeline/02_verify_bodies.py` | the same workbook (`Merged_corpus`, falling back to `All_classified`), **plus live internet** — it fetches each flagged article URL | the `Body_verified` sheet, **back into the workbook it was given** |
| `media_pipeline/03_media_merge_dedup.py` | the same workbook (`Merged_corpus`) **plus** the raw ProQuest `.xls` exports, passed as a glob | with `--out FILE.xlsx`: the merged, deduplicated corpus.<br>Always prints match / MediaCloud-only / ProQuest-only counts. |

**Step 2** (`01`) sorts each article title into one of seven categories — `Miyawaki`,
`Likely_Miyawaki`, `Review_Afforestation`, `Review_Reforestation`, `Review_UrbanForest`,
`Review_GreenCover`, `Not_Miyawaki` — the classification shown in the media-workflow
supplementary figure. `Review_*` rows are flagged for body verification at Step 3.

**Step 3** (`02`) takes a workbook whose titles are already classified and decides, from the
article body, whether each flagged article is really about Mini Forests (`About_Miyawaki` /
`Passing_Mention` / `Likely_About_Miyawaki_RawHTML` / `No_Mention` / `Fetch_Failed` /
`Extract_Failed`). Resumable on URL key. It **modifies the workbook in place** — work on a copy
to leave the deposited file intact. It skips ProQuest-only rows, whose URLs cannot be fetched
programmatically.

**Step 4** (`03`) matches a MediaCloud row to a ProQuest row when the canonical outlet is equal,
the publish dates are within ±1 day, and the Jaccard token overlap of the normalised titles is
≥ 0.70. Run against the four ProQuest exports it reproduces 683 matches / 1,645 MediaCloud-only
/ 2,692 ProQuest-only.

Step 1 (the MediaCloud and ProQuest keyword searches) and Step 5 (manual relevance curation in
Excel, colour-as-truth) are performed by hand and have no script; the curation colours are
preserved in the deposited workbook.

## R — municipality costs

| Script | Reads | Writes |
|---|---|---|
| `costs/R/01_cost_summary.R` | `data/planting_costs.csv` | `table1_summary.csv`<br>`matched_comparisons.csv` |
| `costs/R/02_locale_classification.R` | `data/EDGE_LOCALE25_US.shp`<br>`data/tiger/tl_2025_{ss}_{cousub,place}.shp`<br>`data/TCUSA_Data2016_2025.xlsx` | `locale_classification.csv` |
| `costs/R/03_tcusa_expenditure.R` | `data/TCUSA_Data2016_2025.xlsx`<br>`locale_classification.csv` (optional) | `tcusa_summary.csv` |

**Order:** `01` → `03` → `02`. `02` consumes `03`'s output and reports unrestricted
statistics if it is absent.

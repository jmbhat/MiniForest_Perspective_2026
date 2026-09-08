# Urban Mini Forests need evidence, not just enthusiasm

Analysis code and data for the Nature Cities Perspective
(Bhatnagar, Hutyra, Raeber, Winbourne, Templer).

The paper has three data components:

1. a **media-coverage corpus** — 5,075 unique English-language news articles, 2015–2025,
   from MediaCloud and ProQuest International Newsstream;
2. an **academic-literature synthesis** — 108 Mini Forest studies from Web of Science,
   Dimensions and Google Scholar, manually assessed for study design and measurement; and
3. a **municipal cost comparison** — capital costs of Mini Forests, individual tree
   plantings and turfgrass across Northeast U.S. municipalities.

See **[MANIFEST.md](MANIFEST.md)** for the exact input and output of every script,
including run-order dependencies. Start there.

## Layout

```
data/                 the three corpus workbooks
figures_and_tables/   scripts for Figures 1, 2, S1 and Table S1
media_pipeline/       media corpus scripts (Steps 2-4)
costs/                municipality cost analysis (own README and data/)
```

## Running it

Run everything from the repository root.

```bash
Rscript figures_and_tables/01_Fig1_media_vs_research.R
Rscript figures_and_tables/02_Fig2_evidence_matrix.R      # must precede TableS1
Rscript figures_and_tables/03_TableS1_evidence_text.R
Rscript figures_and_tables/04_FigS1_combined_evidence.R
```

Each script writes its figures and tables into the directory you run it from; the
repository tracks no generated output, and `.gitignore` keeps those files untracked.

**R** needs `tidyverse`, `readxl`, `ggplot2`, `svglite` and `ragg`.

**Python 3.10+** for the media pipeline: `pip install -r media_pipeline/requirements.txt`.
Step 3 fetches live article URLs, so run it on a network that can reach news domains.

```bash
python media_pipeline/01_title_classifier.py data/Mini_Forest_merged_media_corpus.xlsx --out classified.xlsx
python media_pipeline/02_verify_bodies.py --xlsx data/Mini_Forest_merged_media_corpus.xlsx
python media_pipeline/03_media_merge_dedup.py data/Mini_Forest_merged_media_corpus.xlsx 'proquest/*.xls' --out merged.xlsx
```

Run without `--out`, `01` and `03` instead report how closely they reproduce the stored
corpus. `02` writes back into the input workbook.

For the cost analysis, see [costs/README.md](costs/README.md); those three scripts run
`01` → `03` → `02` and need public data files.

### A note on PDF fonts

The figure scripts request `cairo_pdf` and fall back to base `pdf()` if cairo is
unavailable. The fallback does **not** embed fonts. On macOS, cairo needs XQuartz
(`brew install --cask xquartz`); without it `capabilities("cairo")` can still report
`TRUE` while the device fails during run.

## A note on terminology

The plantings are called **Mini Forests** throughout this repository. The word "Miyawaki"
is retained in three places, where changing it would be inaccurate or would break the code:

- **the media search term** — the MediaCloud and ProQuest queries searched for
  `Miyawaki`, and the manuscript's Supplementary Methods reproduces those Boolean strings as run;
- **classification values in the data** — `Miyawaki`, `Likely_Miyawaki`, `Not_Miyawaki`,
  `About_Miyawaki`, `Likely_About_Miyawaki_RawHTML` are stored category labels in the
  deposited workbooks, and the scripts match against them;
- **published paper titles and the author name** in the academic corpus — 52 study
  titles contain "Miyawaki", as does the citation "Miyawaki 1993", Akira Miyawaki's
  own paper.

## Scope of this deposit

This contains the code that produced the published results. Media Steps 2–4 are in `media_pipeline/`,
Step 3's output (`Body_verified`) and the curated corpus are in the deposited workbook, and
Steps 1 and 5 are manual (keyword searching and Excel curation respectively). The Step 2 and Step 4 scripts encode the rules given in the manuscript's Supplementary Methods (title-classifier categories; dedup keys).

## Data availability and provenance

The three workbooks in `data/` are the working dataset reported in the manuscript. Costs for six of the eight Mini Forests are capital costs reported in published benefit–cost analyses of those projects, so that dataset is not independent of the grey
literature; see `costs/README.md` for the full provenance and limitations.

## License

[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)
— see [LICENSE](LICENSE). You may share and adapt the code and data, including
commercially, provided you give appropriate credit.

Please cite the paper:

> Bhatnagar, J.M., Hutyra, L.R., Raeber, M., Winbourne, J.B. & Templer, P.H.
> Urban Mini Forests need evidence, not just enthusiasm. *Nature Cities* (in review).

Note that the media corpora are derived from MediaCloud and ProQuest International
Newsstream records. The bibliographic metadata is redistributed here for
reproducibility; the underlying article full texts remain the property of their
publishers and are not included.

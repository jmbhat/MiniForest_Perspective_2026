# Cost analysis of Mini Forests, individual tree plantings and turfgrass in Northeast U.S. municipalities

Analysis code supporting [manuscript citation].

This repository reproduces the municipal cost comparison in Table 1 and the
urban forestry expenditure analysis reported in the main text and Supplementary
Methods.

## Contents

```
data/
  planting_costs.csv            municipal cost data, one row per planting, with per-row source
  TCUSA_Data2016_2025.xlsx      NOT INCLUDED - see Data sources below
  EDGE_LOCALE25_US.*            NOT INCLUDED - see Data sources below
  tiger/tl_2025_{ss}_{cousub,place}.*   NOT INCLUDED - see Data sources below
R/
  01_cost_summary.R            Table 1 statistics; within-municipality matched comparisons
  03_tcusa_expenditure.R       municipal expenditure distributions and affordability shares
  02_locale_classification.R   NCES City/Suburb/Town/Rural classification
                         written by the scripts
```

Run in order. `02` uses the output of `03` if present, and reports unrestricted
statistics only if it is absent.

```bash
Rscript R/01_cost_summary.R
Rscript R/02_locale_classification.R
Rscript R/03_tcusa_expenditure.R
```

Requires the R packages `sf` (for the point-in-polygon overlay in `03`) and `readxl`.

## Data sources

`planting_costs.csv` is included. Costs were obtained by direct solicitation
from municipal staff, from municipal procurement records, and from published
technical reports; the `source` column records the provenance of each row.
Costs for six of the eight Mini Forests are the capital costs reported in
published benefit–cost analyses of those projects, so the dataset is not
independent of that grey literature.

The remaining inputs are public but too large to redistribute here.

| File | Source |
|---|---|
| `TCUSA_Data2016_2025.xlsx` | Arbor Day Foundation, Tree City USA programme data |
| `EDGE_LOCALE25_US.*` | NCES, https://nces.ed.gov/programs/edge/Geographic/LocaleBoundaries |
| `tl_2025_{ss}_cousub.zip`, `tl_2025_{ss}_place.zip` | Census TIGER/Line 2025, https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html |

TIGER/Line files are needed for the nine Northeast state FIPS codes: 09, 23,
25, 33, 34, 36, 42, 44, 50. Unzip them into `data/tiger/`. The NCES shapefile
requires its `.dbf`, `.shx` and `.prj` companions, not the `.shp` alone.

## Method notes

**Units.** 1 ft² = 0.09290304 m² exactly; 1 ha = 107,639.104 ft². Per-hectare
costs are extrapolated from parcels of 51–1,347 m² and are reported only for
comparison with published international estimates.

**Central tendency.** Medians throughout. Northeast planting expenditures have
a skewness of 23.5 and a mean-to-median ratio of 17.7, with 94% of
municipalities below the mean; a single municipality accounts for 69% of
regional planting expenditure, and removing it shifts the mean by 69% and the
median by 0.6%. `03_tcusa_expenditure.R` prints these diagnostics.

**No inferential statistics.** Municipalities were not randomly sampled.
Comparisons between planting types are made within municipalities; the four
matched comparisons available are reported individually rather than pooled.

**Matched comparison.** Cross-municipality cost ratios confound planting method
with procurement model. Only Brookline, Providence and Worcester reported both
Mini Forest and individual tree costs, and they disagree in direction, which is
the substantive result. Street and park trees have no areal footprint, so
per-area comparison against them is undefined.

**Urban and suburban classification.** The Census urban–rural classification is
binary and places suburban territory inside urban areas, so it cannot isolate
suburbs. The NCES urban-centric locale framework is built on the same Census
urbanized areas but separates principal cities (codes 11–13) from surrounding
urbanized territory (21–23). `02_locale_classification.R` assigns each
municipality the locale of its Census interior point.

**Name matching.** Tree City USA records names without legal suffixes and with
inconsistent formatting. Matching is tiered and the tier is recorded per
municipality in `locale_classification.csv` for audit: 493 exact, 53
resolved from a place/township conflict in favour of the incorporated place, 33
matched only to a census designated place, 1 arbitrary, 12 unmatched and
excluded. Resolving the 53 conflicts to the township instead changes the
City-or-Suburb count from 412 to 408 and leaves the reported medians and
percentages unchanged.

## Known limitations

- Municipal costs are a convenience sample of municipalities known to have
  installed Mini Forests, not a representative regional sample.
- Reported costs differ in accounting scope; the scope columns in
  `planting_costs.csv` record what each figure includes. No Mini Forest
  includes paid planting labour, while five of six individual tree costs do,
  so Mini Forest costs are understated relative to individual trees.
- The Worcester consultancy contract also covered design work unrelated to the
  forests, so that cost is an upper bound.
- Tree City USA participation is voluntary and conditional on an existing
  forestry programme, so the sample is censored toward better-resourced
  municipalities and the affordability percentages are conservative.
- Expenditures are self-reported without audit and with no standard fiscal
  year.

## License

[Choose one - MIT or CC-BY are typical for analysis code accompanying a paper.]

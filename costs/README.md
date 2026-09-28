# Cost analysis of Mini Forests, individual tree plantings and turfgrass in Northeast U.S. municipalities

Analysis code supporting the Perspective (Bhatnagar, Hutyra, Raeber, Winbourne, Templer). This repository reproduces the municipal cost comparisons in Table 1 and the expenditure analysis reported in the main text and Supplementary Methods.

## Contents

```
data/
  planting_costs.csv            municipal cost data, one row per planting, plus source
  TCUSA_Data2016_2025.xlsx      NOT INCLUDED - see Data sources below
  EDGE_LOCALE25_US.*            NOT INCLUDED - see Data sources below
  tiger/tl_2025_{ss}_{cousub,place}.*   NOT INCLUDED - see Data sources below
R/
  01_cost_summary.R            Table 1 statistics; within-municipality matched comparisons
  02_locale_classification.R   NCES City/Suburb/Town/Rural classification
  03_tcusa_expenditure.R       municipal expenditure distributions and affordability calculations

```
Requires the R packages `sf` (for the point-in-polygon overlay in `03`) and `readxl`.

## Data sources

`planting_costs.csv` is included. Costs were obtained by direct solicitation from municipal staff, from municipal procurement records, and from published technical reports; the `source` column records the source of each row. Costs for six of the eight Mini Forests are the capital costs reported in
published benefit–cost analyses of those projects. The remaining inputs are public but too large to redistribute here.

| File | Source |
|---|---|
| `TCUSA_Data2016_2025.xlsx` | Arbor Day Foundation, Tree City USA program data |
| `EDGE_LOCALE25_US.*` | NCES, https://nces.ed.gov/programs/edge/Geographic/LocaleBoundaries |
| `tl_2025_{ss}_cousub.zip`, `tl_2025_{ss}_place.zip` | Census TIGER/Line 2025, https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html |

TIGER/Line files are needed for the nine Northeast state FIPS codes: 09, 23, 25, 33, 34, 36, 42, 44, 50. Unzip them into `data/tiger/`. The NCES shapefile requires its `.dbf`, `.shx` and `.prj` companions, not the `.shp` alone.

## Method notes

**Units.** 1 ft² = 0.09290304 m²; 1 ha = 107,639.104 ft² Per-hectare costs are extrapolated from parcels of 51–1,347 m².

**Data skew.** We report medians throughout, because Northeast planting expenditures have a skewness of 23.5 and a mean-to-median ratio of 17.7, with 94% of municipalities below the mean; a single municipality accounts for 69% of regional planting expenditure and removing it shifts the mean by 69% and the median by 0.6%. `03_tcusa_expenditure.R` calculates and outputs these diagnostics.

**No statistical tests were completed.** Municipalities were not randomly sampled, so comparisons between planting types are only made within municipalities.

**Matched greenspace comparison.** Only Brookline, Providence and Worcester reported both Mini Forest and individual tree costs. 

**Urban and suburban classification.** The Census urban–rural classification is binary and places suburban territory inside urban areas. The NCES urban-centric locale framework is built on the same Census urbanized areas but separates principal cities (codes 11–13) from surrounding urbanized territory (21–23). `02_locale_classification.R` classifies each municipality by the lat/long of its Census interior point.

**Name matching.** Tree City USA records names without legal suffixes and with inconsistent formatting. Matching city names in the Tree City USA dataset and the NCES dataset is tiered and recorded per municipality in `locale_classification.csv`.

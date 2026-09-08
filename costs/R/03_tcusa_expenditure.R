# 02_tcusa_expenditure.R
# -----------------------------------------------------------------------------
# Summarises annual municipal urban forestry expenditure in the Northeast U.S.
# from the Arbor Day Foundation Tree City USA programme, and computes the share
# of municipalities whose entire annual planting budget falls below the capital
# cost of a single Mini Forest.
#
# Input : TCUSA_Data2016_2025.xlsx        (obtain from the Arbor Day Foundation)
#         output/locale_classification.csv (optional; produced by 03_*.R)
# Output: output/tcusa_summary.csv
#         console summary
#
# NOT INCLUDED IN THE REPO: the .xlsx must be obtained from the Arbor Day
# Foundation and placed at the path in STEP 2 before this script will run.
#
# Sample caveats  Tree City USA participation is voluntary and conditional on a
#   tree board, a tree-care ordinance, a minimum per-capita forestry
#   expenditure and an annual Arbor Day observance. The sample is censored
#   toward municipalities with an established forestry programme, so the
#   percentages here are conservative. Expenditures are self-reported without
#   audit and the programme defines no standard fiscal year.
#
# Run each STEP one at a time and inspect the named object it leaves behind.
# =============================================================================

library(readxl)                                                     # read the Arbor Day .xlsx


# STEP 1 -- constants: reporting year, region, money columns, reference costs -
SHEET <- "Tree City USA 2016-2025"                                  # worksheet name inside the workbook
YEAR  <- 2025                                                       # reporting year analysed
NORTHEAST <- c("Connecticut", "Maine", "Massachusetts", "New Hampshire",
               "New Jersey", "New York", "Pennsylvania", "Rhode Island", "Vermont")
MONEY <- c("Planting Costs", "Maintenance Costs", "Removal Costs",
           "Management Costs", "Utility Line Clearance", "Other Expenditures",
           "Total dollars")                                         # columns to coerce to numeric
MINI_FOREST_MEDIAN <- 44450                                         # from 01_cost_summary.R (Table 1)
MINI_FOREST_MIN    <- 7100                                          # cheapest Mini Forest
MINI_FOREST_MAX    <- 466000                                        # most expensive Mini Forest


# STEP 2 -- read the workbook and coerce the money columns -------------------
tcusa_raw <- as.data.frame(read_excel(
  "data/TCUSA_Data2016_2025.xlsx",
  sheet = SHEET))                                                   # every municipality-year record, all states
tcusa_raw[MONEY] <- lapply(tcusa_raw[MONEY], function(x) suppressWarnings(as.numeric(x)))  # text -> numeric, bad cells to NA
str(tcusa_raw[, c("Community", "State", "Year", MONEY)])           # <-- look: money columns now numeric


# STEP 3 -- filter to the Northeast reporting year, PRIMARY dedup rule -------
# The raw file carries duplicate municipality-year records (121 nationally, 54
# in the Northeast). Primary rule: keep the LARGER "Total dollars" of each pair.
# Sort ascending, then keep the last of each Community+State group.
ne <- tcusa_raw[tcusa_raw$Year == YEAR & tcusa_raw$State %in% NORTHEAST, ]  # Northeast, reporting year
n_raw <- nrow(ne)                                                   # record count before deduplication
ne <- ne[order(ne$"Total dollars"), ]                              # ascending by total spend
ne <- ne[!duplicated(ne[, c("Community", "State")], fromLast = TRUE), ]  # keep LAST (largest) per municipality
cat(sprintf("  %d records -> %d municipalities after deduplication (kept larger of each duplicate pair)\n",
            n_raw, nrow(ne)))                                       # <-- look: 54 duplicates collapsed


# STEP 4 -- worked describe(), by hand: all-municipality planting expenditure -
# The reported statistics are median, IQR, mean and the share of municipalities
# spending less than a Mini Forest. Positive expenditures only (a zero or NA is
# "did not report planting spend"). Work the planting column through explicitly.
pv <- ne$"Planting Costs"                                           # planting expenditure column
pv <- pv[!is.na(pv) & pv > 0]                                      # keep reported, positive values only
row_plant_all <- data.frame(
  subset = "all municipalities: planting",
  n      = length(pv),
  median = median(pv),
  q25    = quantile(pv, 0.25, names = FALSE),                      # 25th percentile
  q75    = quantile(pv, 0.75, names = FALSE),                      # 75th percentile
  mean   = mean(pv),
  min    = min(pv),
  max    = max(pv),
  pct_below_median_forest   = mean(pv < MINI_FOREST_MEDIAN) * 100, # % spending less than a median Mini Forest
  pct_below_cheapest_forest = mean(pv < MINI_FOREST_MIN)    * 100, # % below the cheapest Mini Forest
  pct_below_largest_forest  = mean(pv < MINI_FOREST_MAX)    * 100, # % below the most expensive Mini Forest
  stringsAsFactors = FALSE)
print(row_plant_all)                                               # <-- look: headline planting-affordability row


# STEP 5 -- the same describe() for all-municipality TOTAL forestry spend -----
tv <- ne$"Total dollars"                                           # total forestry expenditure column
tv <- tv[!is.na(tv) & tv > 0]                                     # reported positive values only
row_total_all <- data.frame(
  subset = "all municipalities: total forestry",
  n      = length(tv),
  median = median(tv),
  q25    = quantile(tv, 0.25, names = FALSE),
  q75    = quantile(tv, 0.75, names = FALSE),
  mean   = mean(tv),
  min    = min(tv),
  max    = max(tv),
  pct_below_median_forest   = mean(tv < MINI_FOREST_MEDIAN) * 100,
  pct_below_cheapest_forest = mean(tv < MINI_FOREST_MIN)    * 100,
  pct_below_largest_forest  = mean(tv < MINI_FOREST_MAX)    * 100,
  stringsAsFactors = FALSE)
print(row_total_all)                                              # <-- look: total-forestry row


# STEP 6 -- OPTIONAL restriction to City-or-Suburb municipalities ------------
# If 03_locale_classification.R has been run, merge its NCES locale codes and
# repeat the two describe() blocks on the urban/suburban subset (locales 11-23).
# If the file is absent, skip and report only the unrestricted rows above.
lc_path <- "locale_classification.csv"
summary_rows <- list(row_plant_all, row_total_all)                # accumulate the summary rows

if (file.exists(lc_path)) {                                        # <-- look: does the locale file exist?
  lc <- read.csv(lc_path, colClasses = c(LOCALE = "character"))    # read with LOCALE as text (leading digits matter)
  ne <- merge(ne, lc[, c("Community", "State", "LOCALE")],
              by = c("Community", "State"), all.x = TRUE)          # attach locale code to each municipality
  urb <- ne[ne$LOCALE %in% c("11", "12", "13", "21", "22", "23"), ]  # NCES City (11-13) or Suburb (21-23)
  urb <- urb[!is.na(urb$LOCALE), ]                                # drop unmatched
  cat(sprintf("\n  City or Suburb (NCES locale 11-23): %d of %d (%.0f%%)\n",
              nrow(urb), nrow(ne), nrow(urb) / nrow(ne) * 100))

  pv_u <- urb$"Planting Costs"; pv_u <- pv_u[!is.na(pv_u) & pv_u > 0]   # urban planting spend, positive only
  summary_rows[[3]] <- data.frame(
    subset = "city+suburb: planting", n = length(pv_u),
    median = median(pv_u), q25 = quantile(pv_u, .25, names = FALSE),
    q75 = quantile(pv_u, .75, names = FALSE), mean = mean(pv_u),
    min = min(pv_u), max = max(pv_u),
    pct_below_median_forest = mean(pv_u < MINI_FOREST_MEDIAN) * 100,
    pct_below_cheapest_forest = mean(pv_u < MINI_FOREST_MIN) * 100,
    pct_below_largest_forest = mean(pv_u < MINI_FOREST_MAX) * 100,
    stringsAsFactors = FALSE)

  tv_u <- urb$"Total dollars"; tv_u <- tv_u[!is.na(tv_u) & tv_u > 0]   # urban total spend, positive only
  summary_rows[[4]] <- data.frame(
    subset = "city+suburb: total forestry", n = length(tv_u),
    median = median(tv_u), q25 = quantile(tv_u, .25, names = FALSE),
    q75 = quantile(tv_u, .75, names = FALSE), mean = mean(tv_u),
    min = min(tv_u), max = max(tv_u),
    pct_below_median_forest = mean(tv_u < MINI_FOREST_MEDIAN) * 100,
    pct_below_cheapest_forest = mean(tv_u < MINI_FOREST_MIN) * 100,
    pct_below_largest_forest = mean(tv_u < MINI_FOREST_MAX) * 100,
    stringsAsFactors = FALSE)
} else {
  cat("\n  [locale_classification.csv not found - run 03_locale_classification.R\n")
  cat("   for the urban/suburban restricted statistics]\n")
}


# STEP 7 -- assemble and write the summary table -----------------------------
tcusa_summary <- do.call(rbind, summary_rows)                      # 2 rows (or 4 if the locale file was present)
View(tcusa_summary)                                               # <-- look: full expenditure summary
write.csv(tcusa_summary,
          "tcusa_summary.csv",
          row.names = FALSE)

for (i in seq_len(nrow(tcusa_summary))) {                          # print each row in the reported layout (display only)
  r <- tcusa_summary[i, ]
  cat(sprintf("\n%s  (n=%d)\n", r$subset, r$n))
  cat(sprintf("  median $%s   IQR $%s-%s\n",
              format(round(r$median), big.mark = ","),
              format(round(r$q25), big.mark = ","), format(round(r$q75), big.mark = ",")))
  cat(sprintf("  %% below median Mini Forest ($%s): %.0f%%\n",
              format(MINI_FOREST_MEDIAN, big.mark = ","), r$pct_below_median_forest))
  cat(sprintf("  %% below cheapest Mini Forest ($%s): %.0f%%\n",
              format(MINI_FOREST_MIN, big.mark = ","), r$pct_below_cheapest_forest))
}


# STEP 8 -- skew diagnostics: why medians, not means ------------------------
# Justification for reporting medians throughout. Computed on the all-
# municipality planting expenditures (positive values), reported in the
# Supplement. scipy.stats.skew uses the biased (population) estimator
# g1 = m3 / m2^(3/2); replicate it exactly with base-R moments.
v   <- ne$"Planting Costs"; v <- v[!is.na(v) & v > 0]              # planting expenditures, positive only
top <- max(v)                                                     # the single largest municipality
v_wo <- v[v < top]                                               # the distribution with that municipality removed
m2  <- mean((v - mean(v))^2)                                     # 2nd central moment (population)
m3  <- mean((v - mean(v))^3)                                     # 3rd central moment (population)
skewness <- m3 / m2^(3/2)                                        # Fisher-Pearson skewness, matches scipy default
cat(sprintf("\n  skewness                     %.1f\n", skewness))                         # <-- look: extreme right skew (~23.5)
cat(sprintf("  mean / median                %.1f\n", mean(v) / median(v)))               # mean-to-median ratio
cat(sprintf("  %% of municipalities < mean   %.0f%%\n", mean(v < mean(v)) * 100))         # share below the mean
cat(sprintf("  largest municipality share   %.0f%% of regional total\n", top / sum(v) * 100))  # one city's dominance
cat(sprintf("  removing it moves the mean   %.0f%%\n", (1 - mean(v_wo) / mean(v)) * 100)) # mean is fragile
cat(sprintf("  removing it moves the median %.1f%%\n", (1 - median(v_wo) / median(v)) * 100)) # median is robust


# STEP 9 -- SENSITIVITY: the alternative deduplication rule ------------------
# Re-derive the Northeast set keeping the SMALLER "Total dollars" of each
# duplicate pair, and confirm the planting median barely moves.
ne_alt <- tcusa_raw[tcusa_raw$Year == YEAR & tcusa_raw$State %in% NORTHEAST, ]
ne_alt <- ne_alt[order(ne_alt$"Total dollars"), ]                 # ascending by total spend
ne_alt <- ne_alt[!duplicated(ne_alt[, c("Community", "State")], fromLast = FALSE), ]  # keep FIRST (smallest)
a <- ne_alt$"Planting Costs"; a <- a[!is.na(a) & a > 0]           # planting spend under the alternative rule
cat(sprintf("\n  SENSITIVITY (dedup keep smaller): median $%s (vs $%s under the primary rule)\n",
            format(round(median(a)), big.mark = ","),
            format(round(tcusa_summary$median[1]), big.mark = ",")))  # <-- look: median stable across the rule

print("Written: output/tcusa_summary.csv")

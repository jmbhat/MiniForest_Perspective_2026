# 01_cost_summary.R
# -----------------------------------------------------------------------------
# Summarises capital costs of Mini Forests, individual tree plantings and
# turfgrass establishment in Northeast U.S. municipalities, and computes the
# within-municipality matched comparisons reported in the main text (Table 1).
#
# Input : planting_costs.csv
# Output: output/table1_summary.csv
#         output/matched_comparisons.csv
#         console summary
#
# Unit conventions      1 ft^2 = 0.09290304 m^2 (exact, international foot)
#                       1 ha   = 10,000 m^2
# Statistical convention  Medians and full ranges throughout. Distributions are
#                       strongly right-skewed and samples are small, so all
#                       values appear in Table 1 and no inferential statistics
#                       are computed (municipalities were not randomly sampled).
#
# Run each STEP one at a time and inspect the named object it leaves behind.
# =============================================================================


# STEP 1 -- unit constants and read the one included data file --------------
SQFT_TO_M2 <- 0.09290304                                              # exact international foot^2 -> m^2
M2_PER_HA  <- 10000                                                  # m^2 per hectare

costs <- read.csv("data/planting_costs.csv",
                   stringsAsFactors = FALSE)                          # one row per planting, per-row source column
head(costs)                                                           # <-- look: 15 rows, 14 columns, types sane?


# STEP 2 -- derive the per-area and per-tree cost metrics --------------------
costs$area_m2     <- costs$area_sqft * SQFT_TO_M2                     # footprint in m^2 (NA for the arealess street trees)
costs$usd_per_m2  <- costs$capital_cost_usd / costs$area_m2           # capital cost per m^2 of footprint
costs$usd_per_ha  <- costs$usd_per_m2 * M2_PER_HA                     # same, extrapolated to a hectare (for intl comparison only)
costs$usd_per_tree <- costs$capital_cost_usd / costs$trees            # capital cost per tree planted
costs$trees_per_m2 <- costs$trees / costs$area_m2                     # planting density
View(costs)                                                          # <-- look: metrics populated only where area/trees exist


# STEP 3 -- subset the three planting types into named frames ----------------
mf <- costs[costs$planting_type == "mini_forest", ]                  # 8 Mini Forests
it <- costs[costs$planting_type == "individual_tree", ]              # 6 individual tree costs
tg <- costs[costs$planting_type == "turfgrass", ]                    # 1 turfgrass figure (Brookline only)
c(mini_forest = nrow(mf), individual_tree = nrow(it), turfgrass = nrow(tg))  # <-- look: 8 / 6 / 1


# STEP 4 -- Table 1 summary, Mini Forests -----------------------------------
# Median and full range for every reported metric. Written out explicitly so
# each number in Table 1 can be read straight off the block.
mf_row <- data.frame(
  planting_type          = "mini_forest",
  n                      = nrow(mf),
  capital_cost_usd_median = median(mf$capital_cost_usd, na.rm = TRUE),  # headline capital cost
  capital_cost_usd_min   = min(mf$capital_cost_usd,  na.rm = TRUE),
  capital_cost_usd_max   = max(mf$capital_cost_usd,  na.rm = TRUE),
  area_m2_median         = median(mf$area_m2,        na.rm = TRUE),
  area_m2_min            = min(mf$area_m2,           na.rm = TRUE),
  area_m2_max            = max(mf$area_m2,           na.rm = TRUE),
  usd_per_m2_median      = median(mf$usd_per_m2,     na.rm = TRUE),      # cost intensity per m^2
  usd_per_m2_min         = min(mf$usd_per_m2,        na.rm = TRUE),
  usd_per_m2_max         = max(mf$usd_per_m2,        na.rm = TRUE),
  usd_per_ha_median      = median(mf$usd_per_ha,     na.rm = TRUE),
  usd_per_ha_min         = min(mf$usd_per_ha,        na.rm = TRUE),
  usd_per_ha_max         = max(mf$usd_per_ha,        na.rm = TRUE),
  trees_median           = median(mf$trees,          na.rm = TRUE),
  trees_min              = min(mf$trees,             na.rm = TRUE),
  trees_max              = max(mf$trees,             na.rm = TRUE),
  trees_per_m2_median    = median(mf$trees_per_m2,   na.rm = TRUE),
  trees_per_m2_min       = min(mf$trees_per_m2,      na.rm = TRUE),
  trees_per_m2_max       = max(mf$trees_per_m2,      na.rm = TRUE),
  usd_per_tree_median    = median(mf$usd_per_tree,   na.rm = TRUE),      # cost per tree
  usd_per_tree_min       = min(mf$usd_per_tree,      na.rm = TRUE),
  usd_per_tree_max       = max(mf$usd_per_tree,      na.rm = TRUE),
  stringsAsFactors = FALSE)
print(mf_row)                                                        # <-- look: Mini Forest Table 1 row


# STEP 5 -- Table 1 summary, individual trees -------------------------------
# Individual trees have no areal footprint, so area/per-area/density metrics are
# undefined and left as NA; plant_purchase_usd is reported where municipalities
# broke it out.
it_row <- data.frame(
  planting_type          = "individual_tree",
  n                      = nrow(it),
  capital_cost_usd_median = median(it$capital_cost_usd, na.rm = TRUE),  # headline per-tree capital cost
  capital_cost_usd_min   = min(it$capital_cost_usd,  na.rm = TRUE),
  capital_cost_usd_max   = max(it$capital_cost_usd,  na.rm = TRUE),
  area_m2_median = NA, area_m2_min = NA, area_m2_max = NA,
  usd_per_m2_median = NA, usd_per_m2_min = NA, usd_per_m2_max = NA,
  usd_per_ha_median = NA, usd_per_ha_min = NA, usd_per_ha_max = NA,
  trees_median = median(it$trees, na.rm = TRUE),
  trees_min    = min(it$trees, na.rm = TRUE),
  trees_max    = max(it$trees, na.rm = TRUE),
  trees_per_m2_median = NA, trees_per_m2_min = NA, trees_per_m2_max = NA,
  usd_per_tree_median = median(it$usd_per_tree, na.rm = TRUE),          # equals capital cost (1 tree each)
  usd_per_tree_min    = min(it$usd_per_tree, na.rm = TRUE),
  usd_per_tree_max    = max(it$usd_per_tree, na.rm = TRUE),
  plant_purchase_usd_median = median(it$plant_purchase_usd, na.rm = TRUE),  # nursery stock only, where reported
  plant_purchase_usd_min    = min(it$plant_purchase_usd, na.rm = TRUE),
  plant_purchase_usd_max    = max(it$plant_purchase_usd, na.rm = TRUE),
  stringsAsFactors = FALSE)
print(it_row)                                                       # <-- look: individual tree Table 1 row


# STEP 6 -- Table 1 summary, turfgrass (single Brookline figure) -------------
tg_row <- data.frame(
  planting_type          = "turfgrass",
  n                      = nrow(tg),
  capital_cost_usd_median = median(tg$capital_cost_usd, na.rm = TRUE),
  capital_cost_usd_min   = min(tg$capital_cost_usd, na.rm = TRUE),
  capital_cost_usd_max   = max(tg$capital_cost_usd, na.rm = TRUE),
  area_m2_median = median(tg$area_m2, na.rm = TRUE),
  area_m2_min    = min(tg$area_m2, na.rm = TRUE),
  area_m2_max    = max(tg$area_m2, na.rm = TRUE),
  usd_per_m2_median = median(tg$usd_per_m2, na.rm = TRUE),               # the figure compared against Mini Forests
  usd_per_m2_min    = min(tg$usd_per_m2, na.rm = TRUE),
  usd_per_m2_max    = max(tg$usd_per_m2, na.rm = TRUE),
  usd_per_ha_median = median(tg$usd_per_ha, na.rm = TRUE),               # per-ha extrapolation (kept for parity with Mini Forests)
  usd_per_ha_min    = min(tg$usd_per_ha, na.rm = TRUE),
  usd_per_ha_max    = max(tg$usd_per_ha, na.rm = TRUE),
  stringsAsFactors = FALSE)
print(tg_row)                                                       # <-- look: turfgrass Table 1 row


# STEP 7 -- assemble and write Table 1 --------------------------------------
# merge (not rbind) because the three rows carry different metric columns; the
# absent ones fill with NA, matching the Python summary layout.
table1_summary <- merge(merge(mf_row, it_row, all = TRUE), tg_row, all = TRUE)  # union of columns, 3 rows
table1_summary <- table1_summary[match(c("mini_forest", "individual_tree", "turfgrass"),
                                       table1_summary$planting_type), ]  # restore the reported row order
View(table1_summary)                                                # <-- look: full Table 1
write.csv(table1_summary,
          "table1_summary.csv",
          row.names = FALSE)


# STEP 8 -- print the Mini Forest detail block ------------------------------
print("======================================================================")
print("MINI FORESTS")
mf_detail <- mf[, c("municipality", "site", "capital_cost_usd", "area_m2",
                    "usd_per_m2", "usd_per_ha", "trees", "trees_per_m2",
                    "usd_per_tree")]                                 # the per-site rows behind the summary
mf_detail[, -(1:2)] <- round(mf_detail[, -(1:2)], 2)               # round the numeric columns for display
print(mf_detail, row.names = FALSE)                                # <-- look: eight Mini Forest sites
cat(sprintf("  median capital  $%s   range $%s-%s\n",
            format(round(median(mf$capital_cost_usd)), big.mark = ","),
            format(round(min(mf$capital_cost_usd)), big.mark = ","),
            format(round(max(mf$capital_cost_usd)), big.mark = ",")))
cat(sprintf("  median USD/m2   $%s   range $%s-%s\n",
            round(median(mf$usd_per_m2)), round(min(mf$usd_per_m2)), round(max(mf$usd_per_m2))))
cat(sprintf("  median USD/tree $%s   range $%s-%s\n",
            round(median(mf$usd_per_tree)), round(min(mf$usd_per_tree)), round(max(mf$usd_per_tree))))


# STEP 9 -- print the individual tree detail block --------------------------
print("======================================================================")
print("INDIVIDUAL TREES")
print(it[, c("municipality", "site", "capital_cost_usd", "plant_purchase_usd")],
      row.names = FALSE)                                            # <-- look: six per-tree costs
cat(sprintf("  median capital $%s   range $%s-%s\n",
            round(median(it$capital_cost_usd)), round(min(it$capital_cost_usd)), round(max(it$capital_cost_usd))))
pp <- it$plant_purchase_usd[!is.na(it$plant_purchase_usd)]          # only where nursery cost was broken out
cat(sprintf("  median plant purchase $%s   range $%s-%s   (n=%d of %d)\n",
            round(median(pp)), round(min(pp)), round(max(pp)), length(pp), nrow(it)))


# STEP 10 -- worked single matched comparison (Brookline), done by hand ------
# The matched comparison is a within-municipality contrast: a Mini Forest's cost
# per tree against that same city's street/park tree cost. Cross-municipality
# ratios confound planting method with procurement model, so only municipalities
# reporting BOTH types are compared. Work Brookline through explicitly first.
bk_forest_cost <- mf[mf$municipality == "Brookline", "capital_cost_usd"]     # Ridley School project total
bk_forest_per_tree <- mf[mf$municipality == "Brookline", "usd_per_tree"]     # its per-tree cost
bk_street_tree <- median(it[it$municipality == "Brookline", "capital_cost_usd"])  # Brookline street tree cost
c(forest_capital = bk_forest_cost,
  forest_per_tree = bk_forest_per_tree,
  street_tree = bk_street_tree,
  ratio_pertree_to_street = bk_forest_per_tree / bk_street_tree,             # <-- look: forest tree cheaper/dearer than a street tree?
  forest_equiv_n_street_trees = bk_forest_cost / bk_street_tree)             # how many street trees the forest budget buys


# STEP 11 -- the matched comparison for every municipality with both types ---
# Only Brookline, Worcester and Providence reported both. Providence has two
# Mini Forest sites, each compared to the single Providence street-tree median.
# One minimal, heavily commented loop that mirrors STEP 10 exactly.
both_muni <- sort(intersect(mf$municipality, it$municipality))       # municipalities reporting both types
both_muni                                                           # <-- look: Brookline, Providence, Worcester

matched_list <- lapply(both_muni, function(m) {                      # one iteration = one municipality (mirrors STEP 10)
  tree_cost <- median(it[it$municipality == m, "capital_cost_usd"])  # that city's street/park tree cost (median if several)
  forests   <- mf[mf$municipality == m, ]                            # every Mini Forest site in that city
  data.frame(
    municipality = m,
    site = forests$site,
    forest_capital_usd  = forests$capital_cost_usd,
    forest_usd_per_tree = forests$usd_per_tree,
    street_tree_usd     = tree_cost,
    ratio_forest_tree_to_street_tree = forests$usd_per_tree / tree_cost,   # per-tree cost ratio
    forest_equiv_n_street_trees      = forests$capital_cost_usd / tree_cost,  # forest budget in street-tree units
    stringsAsFactors = FALSE)
})
matched_comparisons <- do.call(rbind, matched_list)                 # stack the per-municipality rows
View(matched_comparisons)                                           # <-- look: 4 rows; do the ratios disagree in direction?
write.csv(matched_comparisons,
          "matched_comparisons.csv",
          row.names = FALSE)
print("======================================================================")
print("MATCHED WITHIN-MUNICIPALITY COMPARISONS")
print(cbind(matched_comparisons[, 1:2], round(matched_comparisons[, -(1:2)], 2)), row.names = FALSE)


# STEP 12 -- turfgrass comparison, Brookline only ----------------------------
# Brookline is the only municipality reporting all three planting types, so the
# Mini-Forest-vs-turfgrass per-m^2 contrast is available there alone.
tg_per_m2 <- tg$usd_per_m2[1]                                        # Larz Anderson Park turfgrass, $/m^2
bk_mf_per_m2 <- mf[mf$municipality == "Brookline", "usd_per_m2"]     # Brookline Mini Forest, $/m^2
cat(sprintf("\nBrookline Mini Forest $%.2f/m2 vs turfgrass $%.2f/m2  ->  %.0fx\n",
            bk_mf_per_m2, tg_per_m2, bk_mf_per_m2 / tg_per_m2))      # <-- look: fold difference
cat("  NOTE: accounting scope differs between these two figures; the Mini Forest\n")
cat("  includes site preparation but not installation labour, the turfgrass the reverse.\n")


# STEP 13 -- street frontage equivalents -------------------------------------
# What length of street frontage would the same money plant, at each city's
# stated on-centre tree spacing? Frontage = n_trees * spacing. Continuous
# plantable frontage is assumed, so these are UPPER bounds (driveways, hydrants,
# vaults and transit stops all interrupt real street runs).
# Worked example, Brookline: $7,100 forest / $620 street tree = n trees @ 25 ft.
bk_n <- 7100 / 620                                                  # street trees the Brookline forest budget buys
bk_frontage_ft <- bk_n * 25                                         # frontage at 25 ft on-centre
bk_frontage_m  <- bk_frontage_ft * 0.3048                           # feet -> metres
c(n_trees = bk_n, frontage_ft = bk_frontage_ft,
  frontage_m = bk_frontage_m, both_sides_m = bk_frontage_m / 2)     # <-- look: Brookline frontage equivalent

# The same computation for the three specification rows (Brookline + two
# Worcester spacings). Explicit, one row per spec.
frontage_specs <- data.frame(
  city    = c("Brookline", "Worcester", "Worcester"),
  cost    = c(7100, 466000, 466000),                               # forest capital cost
  tree    = c(620, 491, 491),                                      # that city's per-street-tree cost
  spacing = c(25, 30, 25),                                         # on-centre spacing, ft
  source  = c("Zoning By-law Art. V 5.06.4.j (Emerald Island Special District)",
              "Streetscape Policy 2012, typical spacing",
              "Streetscape Policy 2012, stated minimum"),
  stringsAsFactors = FALSE)
frontage_specs$n_trees      <- frontage_specs$cost / frontage_specs$tree           # trees the budget buys
frontage_specs$frontage_m   <- frontage_specs$n_trees * frontage_specs$spacing * 0.3048  # frontage in metres
frontage_specs$both_sides_m <- frontage_specs$frontage_m / 2                       # street length if planted both sides
print("======================================================================")
print("STREET FRONTAGE EQUIVALENTS")
View(frontage_specs)                                                # <-- look: frontage upper bounds per spec

print("Written: output/table1_summary.csv")
print("Written: output/matched_comparisons.csv")

# 03_locale_classification.R
# -----------------------------------------------------------------------------
# Classifies Tree City USA municipalities as City, Suburb, Town or Rural using
# the NCES urban-centric locale framework, by point-in-polygon overlay of Census
# municipal interior points against the NCES locale boundary file.
#
# Inputs (all public; NONE included in the repo -- see README for sources)
#   EDGE_LOCALE25_US.shp             NCES locale boundaries (+ .dbf .shx .prj)
#   tiger/tl_2025_{ss}_cousub.shp    Census county subdivisions   (9 NE states)
#   tiger/tl_2025_{ss}_place.shp     Census incorporated places   (9 NE states)
#   TCUSA_Data2016_2025.xlsx         Arbor Day Foundation
# Output
#   output/locale_classification.csv
#   console summary
#
# Why NCES rather than the Census urban-rural split: the Census split is binary
# (suburban territory is simply "urban", with no suburb category). NCES is built
# on the same Census urbanized areas but separates principal cities (11-13) from
# surrounding urbanized territory (21-23), permitting a City-or-Suburb subset.
#
# Requires the 'sf' and 'readxl' packages. Run each STEP one at a time.
# =============================================================================

library(sf)                                                        # spatial read + point-in-polygon join
library(readxl)                                                    # read the Arbor Day .xlsx

sf::sf_use_s2(FALSE)                                               # planar (GEOS) overlay, matching Python/geopandas;
                                                                   # the NCES locale polygons carry duplicate-vertex loops
                                                                   # that the spherical s2 engine rejects, and a point-in-
                                                                   # polygon test is unaffected by the planar/spherical choice


# STEP 1 -- lookups: state FIPS, locale labels, the urban set, matching rules -
STATE_FIPS <- c("09" = "Connecticut", "23" = "Maine", "25" = "Massachusetts",
                "33" = "New Hampshire", "34" = "New Jersey", "36" = "New York",
                "42" = "Pennsylvania", "44" = "Rhode Island", "50" = "Vermont")
LOCALE_LABEL <- c("11" = "City, Large", "12" = "City, Midsize", "13" = "City, Small",
                  "21" = "Suburb, Large", "22" = "Suburb, Midsize", "23" = "Suburb, Small",
                  "31" = "Town, Fringe", "32" = "Town, Distant", "33" = "Town, Remote",
                  "41" = "Rural, Fringe", "42" = "Rural, Distant", "43" = "Rural, Remote")
URBAN_SUBURBAN <- c("11", "12", "13", "21", "22", "23")            # NCES City (11-13) or Suburb (21-23)
CDP_LSAD    <- "57"                                                # census designated place: not a governing entity
LEGAL_SUFFIX <- "\\s+(borough|boro|township|twp|village|town|city)$"  # trailing legal suffix to strip when matching
TIGER_DIR <- "data/tiger"
LOCALE_SHP <- "data/EDGE_LOCALE25_US.shp"


# STEP 2 -- read the NCES locale boundary layer ------------------------------
locale <- st_read(LOCALE_SHP, quiet = TRUE)                        # locale polygons, one LOCALE code each
cat(sprintf("  NCES locale polygons: %s (CRS: %s)\n",
            format(nrow(locale), big.mark = ","), st_crs(locale)$input))  # <-- look: layer read, CRS known


# STEP 3 -- worked single shapefile: one state's county subdivisions ---------
# The reference layer is one row per Census geography carrying its interior
# point. County subdivisions are the municipal unit in the six New England
# states (and townships in NY/NJ/PA); incorporated places cover cities,
# boroughs and villages. Work ONE file through by hand before looping.
g1 <- st_read(file.path(TIGER_DIR, "tl_2025_25_cousub.shp"), quiet = TRUE)  # Massachusetts county subdivisions
g1 <- g1[g1$ALAND > 0, ]                                          # drop water-only records
example_cousub <- data.frame(
  State = STATE_FIPS[substr(g1$STATEFP, 1, 2)],                   # FIPS -> state name
  NAME  = g1$NAME,                                                # bare municipality name
  NAMELSAD = g1$NAMELSAD,                                         # name with legal/statistical suffix
  kind  = "cousub",                                              # geography kind
  is_cdp = FALSE,                                               # cousubs are never CDPs
  lat = as.numeric(g1$INTPTLAT),                                # interior point latitude  (+dd.dddd)
  lon = as.numeric(g1$INTPTLON),                                # interior point longitude (-dd.dddd)
  stringsAsFactors = FALSE)
head(example_cousub)                                             # <-- look: one file parsed into the reference shape


# STEP 4 -- read all 18 shapefiles into one reference frame ------------------
# One minimal loop that mirrors STEP 3 exactly, over the 9 states x 2 geography
# kinds (cousub + place). This is genuine iteration over files, so it is the
# single loop the analysis needs; everything downstream is vectorised.
fips  <- names(STATE_FIPS)                                        # the 9 Northeast state FIPS codes
specs <- rbind(data.frame(ss = fips, kind = "cousub", stringsAsFactors = FALSE),
               data.frame(ss = fips, kind = "place",  stringsAsFactors = FALSE))  # 18 (state, kind) jobs

ref_parts <- vector("list", nrow(specs))                         # one list slot per shapefile
for (i in seq_len(nrow(specs))) {                                # i-th shapefile (mirrors STEP 3)
  fp <- file.path(TIGER_DIR, sprintf("tl_2025_%s_%s.shp", specs$ss[i], specs$kind[i]))
  g  <- st_read(fp, quiet = TRUE)                                # read this state+kind layer
  g  <- g[g$ALAND > 0, ]                                        # drop water-only records
  ref_parts[[i]] <- data.frame(
    State  = STATE_FIPS[specs$ss[i]],                            # state name from FIPS
    NAME   = g$NAME,
    NAMELSAD = g$NAMELSAD,
    kind   = specs$kind[i],
    is_cdp = specs$kind[i] == "place" & g$LSAD == CDP_LSAD,      # a place is a CDP when its LSAD is 57
    lat    = as.numeric(g$INTPTLAT),
    lon    = as.numeric(g$INTPTLON),
    stringsAsFactors = FALSE)
}
ref <- do.call(rbind, ref_parts)                                # stack all 18 layers into one reference frame
cat(sprintf("  reference geographies: %s (cousub %s, place %s)\n",
            format(nrow(ref), big.mark = ","),
            format(sum(ref$kind == "cousub"), big.mark = ","),
            format(sum(ref$kind == "place"), big.mark = ",")))   # <-- look: total reference geographies


# STEP 5 -- normalise names into a match key (vectorised, no loop) -----------
# Lower-case, unify punctuation, expand common directional/abbreviation
# prefixes, then strip any trailing legal suffix. Applied to the whole NAME
# column at once with vectorised gsub -- this is the Python normalise()/basename().
key <- tolower(trimws(ref$NAME))                                 # lower-case, trim
key <- gsub("[-.]", " ", key)                                   # hyphens and dots -> spaces
key <- gsub("['`]", "", key)                                    # drop apostrophes/backticks
key <- gsub("^w\\s+", "west ",  key); key <- gsub("^e\\s+", "east ",  key)   # W./E. prefixes
key <- gsub("^n\\s+", "north ", key); key <- gsub("^s\\s+", "south ", key)   # N./S. prefixes
key <- gsub("^st\\s+", "saint ", key); key <- gsub("^mt\\s+", "mount ", key) # St./Mt. prefixes
key <- gsub("\\s+", " ", key)                                   # collapse repeated spaces
key <- trimws(gsub(LEGAL_SUFFIX, "", key))                      # strip trailing legal suffix -> match key
ref$key <- key                                                 # attach the key to the reference frame
head(ref[, c("State", "NAME", "key", "kind", "is_cdp")])       # <-- look: names reduced to bare match keys


# STEP 6 -- point-in-polygon: assign each geography its NCES locale ----------
# Build interior points in the locale layer's CRS (mirrors the Python, which
# assigns the locale CRS directly to the lon/lat points), then keep the locale
# polygon each point falls within.
pts <- st_as_sf(ref, coords = c("lon", "lat"), crs = st_crs(locale))  # interior points as sf, locale CRS
joined <- st_join(pts, locale["LOCALE"], join = st_within)            # locale code of the containing polygon
joined <- st_drop_geometry(joined)                                   # back to a plain data frame
joined <- joined[!duplicated(joined[, c("State", "key", "kind", "NAMELSAD")]), ]  # one row per geography
ref <- joined[!is.na(joined$LOCALE), c("State", "key", "NAME", "NAMELSAD", "kind", "is_cdp", "LOCALE")]
n_missing <- sum(is.na(joined$LOCALE))                              # points outside every locale polygon
if (n_missing) cat(sprintf("  %d interior points fell outside all locale polygons; dropped\n", n_missing))
cat(sprintf("  geographies with a locale: %s\n", format(nrow(ref), big.mark = ",")))  # <-- look: reference ready


# STEP 7 -- read Tree City USA, filter to the Northeast reporting year -------
df <- as.data.frame(read_excel(
  "data/TCUSA_Data2016_2025.xlsx",
  sheet = "Tree City USA 2016-2025"))
df$"Total dollars" <- suppressWarnings(as.numeric(df$"Total dollars"))       # coerce for the dedup sort
ne <- df[df$Year == 2025 & df$State %in% STATE_FIPS, ]                       # Northeast, reporting year
ne <- ne[order(ne$"Total dollars"), ]                                       # ascending by total spend
ne <- ne[!duplicated(ne[, c("Community", "State")], fromLast = TRUE), ]      # keep the larger of each duplicate pair

# Normalise the TCUSA community names with the SAME vectorised rules as STEP 5.
k <- tolower(trimws(ne$Community)); k <- gsub("[-.]", " ", k); k <- gsub("['`]", "", k)
k <- gsub("^w\\s+", "west ", k); k <- gsub("^e\\s+", "east ", k)
k <- gsub("^n\\s+", "north ", k); k <- gsub("^s\\s+", "south ", k)
k <- gsub("^st\\s+", "saint ", k); k <- gsub("^mt\\s+", "mount ", k)
k <- gsub("\\s+", " ", k); ne$key <- trimws(gsub(LEGAL_SUFFIX, "", k))       # match key per municipality
cat(sprintf("  Tree City USA municipalities: %s\n", format(nrow(ne), big.mark = ",")))  # <-- look: municipalities to classify


# STEP 8 -- worked single resolve(), by hand: one municipality ---------------
# Assign a municipality its locale by matching its key to the reference. Tiers:
#   exact              one incorporated geography matched
#   conflict-resolved  a place and a coincident township disagreed; resolved to
#                      the preferred kind ("place" for the primary result)
#   conflict-arbitrary still disagreed; lowest code taken
#   cdp                matched only a census designated place (locates it, but
#                      the CDP is not the governing entity)
#   unmatched          no match; excluded
# Work the first municipality through explicitly.
s1 <- ne$State[1]; k1 <- ne$key[1]                                # first municipality's state and key
inc1 <- ref[!ref$is_cdp & ref$State == s1 & ref$key == k1, ]      # incorporated (non-CDP) matches
codes1 <- unique(inc1$LOCALE)                                     # distinct locale codes among them
pref1  <- inc1[inc1$kind == "place", ]                            # the "place" candidates (primary preference)
c(state = s1, key = k1, n_incorporated = nrow(inc1),
  n_distinct_codes = length(codes1))                              # <-- look: how this one municipality matched


# STEP 9 -- resolve every municipality: one minimal loop mirroring STEP 8 ----
# Fills the primary locale + tier (prefer "place") and the sensitivity locale
# (prefer "cousub"). Vectors are pre-allocated; the loop body is STEP 8 with the
# tier decisions written out, run once per municipality.
n <- nrow(ne)
LOCALE     <- rep(NA_character_, n)                               # primary locale code
match_tier <- rep(NA_character_, n)                               # tier used for the primary code
LOCALE_alt <- rep(NA_character_, n)                               # sensitivity code (prefer township)
for (i in seq_len(n)) {                                          # i-th municipality (mirrors STEP 8)
  s <- ne$State[i]; ky <- ne$key[i]
  inc <- ref[!ref$is_cdp & ref$State == s & ref$key == ky, ]     # incorporated matches for this municipality

  if (nrow(inc) == 0) {                                          # no incorporated match ...
    cdp <- ref[ref$is_cdp & ref$State == s & ref$key == ky, ]    # ... fall back to a CDP
    if (nrow(cdp)) { LOCALE[i] <- sort(unique(cdp$LOCALE))[1]; match_tier[i] <- "cdp" }
    else           { match_tier[i] <- "unmatched" }              # ... otherwise excluded
  } else {
    codes <- unique(inc$LOCALE)
    if (length(codes) == 1) {                                    # one code: unambiguous
      LOCALE[i] <- codes; match_tier[i] <- "exact"
    } else {
      pref <- inc[inc$kind == "place", ]                         # prefer the incorporated PLACE
      if (nrow(pref) && length(unique(pref$LOCALE)) == 1) {
        LOCALE[i] <- unique(pref$LOCALE); match_tier[i] <- "conflict-resolved"
      } else {                                                  # still disagree: take the lowest code
        LOCALE[i] <- sort(codes)[1]; match_tier[i] <- "conflict-arbitrary"
      }
    }
  }

  # Sensitivity: same logic but prefer the township (cousub) when codes conflict.
  if (nrow(inc) == 0) {
    cdp <- ref[ref$is_cdp & ref$State == s & ref$key == ky, ]
    LOCALE_alt[i] <- if (nrow(cdp)) sort(unique(cdp$LOCALE))[1] else NA_character_
  } else {
    codes <- unique(inc$LOCALE)
    if (length(codes) == 1) {
      LOCALE_alt[i] <- codes
    } else {
      pref <- inc[inc$kind == "cousub", ]                        # prefer the TOWNSHIP here
      LOCALE_alt[i] <- if (nrow(pref) && length(unique(pref$LOCALE)) == 1)
        unique(pref$LOCALE) else sort(codes)[1]
    }
  }
}
ne$LOCALE <- LOCALE                                             # attach primary code
ne$match_tier <- match_tier                                    # attach tier
ne$LOCALE_alt <- LOCALE_alt                                    # attach sensitivity code
ne$locale_label <- LOCALE_LABEL[ne$LOCALE]                     # human-readable label
ne$urban_suburban <- ne$LOCALE %in% URBAN_SUBURBAN             # TRUE for City or Suburb


# STEP 10 -- audit: match tiers and locale distribution ----------------------
print("  match tiers:")
print(table(ne$match_tier))                                    # <-- look: exact / conflict-resolved / cdp / unmatched counts
print("  locale distribution:")
loc_tab <- table(factor(ne$LOCALE, levels = names(LOCALE_LABEL)))  # ordered by locale code
print(data.frame(code = names(loc_tab),
                 label = LOCALE_LABEL[names(loc_tab)],
                 n = as.integer(loc_tab),
                 pct = round(as.integer(loc_tab) / nrow(ne) * 100, 1),
                 row.names = NULL))                            # <-- look: City/Suburb/Town/Rural spread


# STEP 11 -- headline City-or-Suburb count and the dedup sensitivity ---------
n_urb <- sum(ne$urban_suburban, na.rm = TRUE)                  # primary City-or-Suburb count
cat(sprintf("\n  City or Suburb: %d of %d (%.0f%%)\n", n_urb, nrow(ne), n_urb / nrow(ne) * 100))
n_alt <- sum(ne$LOCALE_alt %in% URBAN_SUBURBAN)               # same count if conflicts go to the township
cat(sprintf("  sensitivity, conflicts resolved to township instead: %d\n", n_alt))
unmatched <- ne$Community[ne$match_tier == "unmatched"]       # municipalities dropped for lack of a match
if (length(unmatched))
  cat(sprintf("\n  unmatched (%d), excluded: %s\n", length(unmatched), paste(unmatched, collapse = ", ")))


# STEP 12 -- write the per-municipality classification -----------------------
out <- ne[, c("Community", "State", "LOCALE", "locale_label", "urban_suburban",
              "match_tier", "LOCALE_alt")]                     # audit columns, one row per municipality
View(out)                                                     # <-- look: full classification with tier per row
write.csv(out,
          "locale_classification.csv",
          row.names = FALSE)
print("Written: output/locale_classification.csv")

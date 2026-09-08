# =============================================================================
# 04_FigS1_combined_evidence.R
# Builds Figure S1, the full per-paper evidence matrix.
#
# Build: Mini_Forest_combined_evidence_figure.{svg,pdf,png} (+ FigureS1_ copies)
#
# Two side-by-side dot matrices over the empirical Mini Forest papers, rows grouped
# by peer-review status x Scopus/WoS indexing (best -> worst):
#   Panel A - measurement matrix: 22 measurement sub-columns in six category
#             bands (CARBON/HEAT/STORM/BIODIVERSITY/WELL-BEING/OTHER); a filled
#             coloured circle = that quantity was measured, open = not.
#             Two text columns sit to the right of the dots: the Quant/Qual
#             DATA TYPE pill (2026-09-07) and Mini Forest age (years).
#   Panel B - design-rigor matrix: 8 criteria; charcoal filled circle = met.
#
# 2026-07-17 (carried from the Python): predatory distinction removed; modeled
# (non-field) studies dropped (they are all Empirical = No, so filtering to
# empirical field studies removes them cleanly).
#
# Source: Mini_Forest_academic_corpus.xlsx (Paper_analysis)
# Packages: readxl, ggplot2, patchwork  (svglite/ragg optional)
# =============================================================================

library(readxl)
library(ggplot2)
library(patchwork)

# ---- font + text sizes (2026-08-04) ----------------------------------------
# Times New Roman throughout, to match Figure 2. Column headers are single-line
# (Panel B's are now rotated like Panel A's so the long phrases fit on one line),
# and the row/column name sizes are enlarged. cairo is unavailable on this
# machine, so the PDF uses a base-R Times alias (see save loop); PNG (ragg) and
# SVG (svglite) render true Times New Roman.
.FIGFONT <- "Times New Roman"
update_geom_defaults("text", list(family = .FIGFONT))
# 2026-08-04: canvas shrunk and panel widths matched to column counts (see the
# save block + plot_layout), so text is no longer tiny; sizes bumped to suit.
SZ_ROW    <- 4.6   # Panel A study row labels
SZ_SEC_T  <- 3.7   # section-header title (e.g. PEER-REVIEWED)
SZ_SEC_S  <- 3.0   # section-header sub / n
SZ_COLA   <- 4.4   # Panel A rotated measurement column headers
SZ_COLB   <- 4.4   # Panel B rotated design-rigor column headers
SZ_BANNER <- 4.8   # category banner labels (CARBON, HEAT, ...) — sized to fit the rotated word
SZ_PILL   <- 3.7   # Quant/Qual data-type pill + Mini Forest age text (matches Figure 2's pill idiom)
SZ_DOT    <- 3.0   # present-dot diameter
SZ_DOT0   <- 2.1   # absent-dot diameter

PAPER_XLSX <- "data/Mini_Forest_academic_corpus.xlsx"
OUTDIR     <- "."

# ---- helpers ----------------------------------------------------------------
yn <- function(x) {
  s <- tolower(trimws(as.character(x)))
  ifelse(is.na(s) | s %in% c("none", "na", ""), NA_character_,
  ifelse(startsWith(s, "yes"), "Yes", ifelse(startsWith(s, "no"), "No", s)))
}

# ---- load paper data (address columns BY HEADER) ----------------------------
raw  <- read_excel(PAPER_XLSX, sheet = "Paper_analysis", col_names = FALSE, .name_repair = "minimal")
hdr  <- as.character(unlist(raw[1, ])); body <- raw[-1, ]
col <- function(...) {
  opts <- tolower(c(...)); low <- tolower(hdr)
  for (o in opts) { i <- which(startsWith(low, o)); if (length(i)) return(i[1]) }
  for (o in opts) { i <- which(grepl(o, low, fixed = TRUE)); if (length(i)) return(i[1]) }
  stop(sprintf("Column not found: %s", paste(opts, collapse = ", ")))
}
C <- list(AUTH = col("Authors"), YEAR = col("Year"), IDX = col("Index"), QD = col("QD"),
          URBAN = col("In urban area"), EMP = col("Empirical data on Miyawaki"),
          MEAS = col("Measurements"), DTYPE = col("Data type"), PR = col("Peer reviewed"), HJ = col("Hijacked", "predatory"),
          CV = col("Comparison to other types of vegetation"),
          CG = col("Comparison to other types of urban greening"),
          CU = col("Comparison to other types of urban tree planting"),
          RM = col("Replicated Miyawaki"), RC = col("Replicated Comparison"),
          SG = col("Statistical tests of claim against other types of urban greening"),
          SP = col("Statistical tests of claim against other types of urban tree planting"),
          AGE = col("Miyawaki forest age"))

Auth  <- as.character(body[[C$AUTH]])
yrcell <- as.character(body[[C$YEAR]])
Year  <- ifelse(grepl("\\d{4}", yrcell), as.integer(regmatches(yrcell, regexpr("\\d{4}", yrcell))), NA_integer_)

P <- data.frame(
  Auth = Auth, Year = Year,
  Idx = yn(body[[C$IDX]]), Urban = yn(body[[C$URBAN]]), Emp = yn(body[[C$EMP]]),
  Pr = yn(body[[C$PR]]), CV = yn(body[[C$CV]]), CG = yn(body[[C$CG]]), CU = yn(body[[C$CU]]),
  RM = yn(body[[C$RM]]), RC = yn(body[[C$RC]]), SG = yn(body[[C$SG]]), SP = yn(body[[C$SP]]),
  Age = trimws(ifelse(is.na(body[[C$AGE]]), "", as.character(body[[C$AGE]]))),   # Mini Forest age (years)
  DTraw = tolower(trimws(ifelse(is.na(body[[C$DTYPE]]), "", as.character(body[[C$DTYPE]])))),  # <-- look: Quantitative / Qualitative / both / Review
  DT = tolower(ifelse(is.na(body[[C$MEAS]]), "", as.character(body[[C$MEAS]]))),
  stringsAsFactors = FALSE)
P <- P[!is.na(P$Auth) & P$Auth != "NA", ]
P <- P[P$Emp == "Yes" & !is.na(P$Emp), ]                              # plotted = empirical field studies
cat(sprintf("Empirical papers plotted: %d\n", nrow(P)))

# ---- Data type (Quant vs. Qual) --------------------------------------------
# 2026-09-07 (JMB): new column, drawn as a pill in the same idiom as Figure 2.
# Figure 2 collapses "Quantitative and Qualitative" into "Quant" (its case_when
# tests startsWith "quant" first); Figure S1 is the complete supplementary
# matrix, so the mixed studies get their own third state here.
P$DType <- ifelse(grepl("quant", P$DTraw, fixed = TRUE) & grepl("qual", P$DTraw, fixed = TRUE), "Quant + Qual",
           ifelse(startsWith(P$DTraw, "quant"), "Quant",
           ifelse(startsWith(P$DTraw, "qual"),  "Qual", "")))          # blank cell / "Review" -> no pill
cat("Data type of plotted papers:\n"); print(table(P$DType, useNA = "ifany"))   # <-- look: 41 / 10 / 5, no blanks

# ---- short citation (first-author surname + year), with overrides -----------
SURNAME_OVERRIDES <- c("anirban roy" = "Roy", "ospina parra" = "Ospina-Parra",
                       "rodrigues brito domingues" = "Rodrigues Brito Domingues",
                       "song k." = "Song", "meguro s.-i." = "Meguro", "s.kothai" = "Kothai")
is_initials <- function(t) grepl("^[A-Z]\\.?([A-Z]\\.?)*$", t) || grepl("^[A-Z]\\.-[A-Z]\\.?$", t)
short_cite <- function(auth, year) {
  raw1 <- trimws(as.character(auth))
  first <- trimws(strsplit(raw1, ";|(?:\\s+and\\s+)", perl = TRUE)[[1]][1])       # first author chunk
  pre   <- if (grepl(",", first, fixed = TRUE)) trimws(strsplit(first, ",", fixed = TRUE)[[1]][1]) else first
  key   <- sub("\\.+$", "", tolower(pre))
  surname <- NA_character_
  for (ok in names(SURNAME_OVERRIDES)) if (startsWith(key, ok)) { surname <- SURNAME_OVERRIDES[[ok]]; break }
  if (is.na(surname)) {
    toks <- strsplit(pre, "\\s+")[[1]]
    if (length(toks) == 1) {
      surname <- toks[1]
      m <- regmatches(surname, regexec("^[A-Z]\\.([A-Z][a-z].*)$", surname))[[1]]  # S.Kothai -> Kothai
      if (length(m) == 2) surname <- m[2]
    } else {
      non_init <- toks[!vapply(toks, is_initials, logical(1))]
      surname <- if (length(non_init)) paste(non_init, collapse = " ") else paste(toks, collapse = " ")
    }
  }
  paste(surname, if (!is.na(year)) as.character(year) else "n.d.")
}
P$sc <- mapply(short_cite, P$Auth, P$Year)
dupc <- table(P$sc)                                                  # disambiguate duplicates with a/b/c
seen <- setNames(integer(length(dupc)), names(dupc))
P$label <- P$sc
for (i in seq_len(nrow(P))) {
  s <- P$sc[i]
  if (dupc[[s]] > 1) { seen[s] <- seen[s] + 1; P$label[i] <- paste0(s, letters[seen[s]]) }
}

# ---- measurement matchers (operate on the lower-cased Measurements text) ----
has_any <- function(s, kws) any(vapply(kws, function(k) grepl(k, s, fixed = TRUE), logical(1)))
m_growth <- function(s) { for (ph in c("soil microbial biomass","microbial biomass","bacterial biomass","fungal biomass")) s <- gsub(ph, "", s, fixed = TRUE)
  has_any(s, c("growth rate","growth rates","growth ","dbh","flowering","fruiting","plant biomass","tree biomass","biomass")) }
m_biomass_C <- function(s) has_any(s, c("carbon stock","c stock","sequestration","c sequestration","carbon sequest","tissue","carbon concentration"))
m_leaves    <- function(s) has_any(s, c("leaf area","leaf #","leaf number","number of leaves","leaves","branch #"))
m_survival  <- function(s) has_any(s, c("mortality","survival"))
m_canopy    <- function(s) has_any(s, c("canopy","plant cover","vegetation cover"))
m_physiology<- function(s) has_any(s, c("photosynthetic activity","photosynthetic rate","stomatal","co2-fixation","co2 fixation","transpiration rate"))
m_soilC     <- function(s) has_any(s, c("som content","som,","soil organic","soil c ","soil %organic","organic carbon","soil carbon")) || (grepl("soil", s, fixed = TRUE) && grepl("carbon concentration", s, fixed = TRUE))
m_air_temp  <- function(s) grepl("\\bair\\s+temp", s, perl = TRUE) || (grepl("temperature", s, fixed = TRUE) && grepl("soil temperature", s, fixed = TRUE)) || grepl("thermal", s, fixed = TRUE)
m_ET        <- function(s) has_any(s, c("evapotrans","water vapor","transpiration rate"))
m_energy    <- function(s) has_any(s, c("energy balance"))
m_water_ret <- function(s) has_any(s, c("water retention","hydraulic"))
m_plant_div <- function(s) has_any(s, c("plant diversity","species diversity","plant species diversity","community composition"))
m_micro     <- function(s) has_any(s, c("microbial diversity","microbial community","bacterial diversity","bacterial community","fungal diversity","fungal community","mushroom"))
m_micro_biomass <- function(s) has_any(s, c("microbial biomass","bacterial biomass","fungal biomass"))
m_animal    <- function(s) has_any(s, c("insect","pollinator","animal"))
m_perception<- function(s) has_any(s, c("perception","perceived","feeling","thought","attitude","opinion","awareness","knowledge","understanding","expectation","experience","sense ","senses ","ownership","place attachment","pride","concern","important elements","discourse","favorability","favourability","acceptance","success or failure"))
m_health    <- function(s) has_any(s, c("mental health","health outcome","exercise","psychophysical"))
m_cost      <- function(s) has_any(s, c("cost"))
m_education <- function(s) has_any(s, c("education","awareness","knowledge"))
m_airq      <- function(s) has_any(s, c("pollutant","dust"))
m_soil_nut  <- function(s) has_any(s, c("micronutrient","ph,","ph ","nutrient content","nutrient,")) || has_any(s, c("soil n,","soil n ","soil p","soil k","exchange capacity"))
m_site_phys <- function(s) has_any(s, c("porosity","bulk density","particle density","texture","respiration rate"))

# category palette
CAT <- c(CARBON = "#2E7D32", HEAT = "#E65100", STORM = "#0277BD",
         BIODIV = "#7E57C2", WELL = "#00897B", OTHER = "#9E9D24")
CAT_BAND_ALPHA <- 0.10
cat_band_label <- c(CARBON = "CARBON", HEAT = "HEAT", STORM = "STORM",
                    BIODIV = "BIODIVERSITY", WELL = "WELL-BEING", OTHER = "OTHER")

# measurement columns, flattened in category order (cat, label, matcher)
measurement_groups <- list(
  # 2026-08-04 (JMB): "Canopy cover" removed; "Soil C / SOM" moved up to 2nd to match Figure 2.
  list("CARBON", list(list("Plant C stocks / sequestration", m_biomass_C), list("Soil C / SOM", m_soilC),
                      list("Plant growth / biomass", m_growth), list("Leaf area / count", m_leaves),
                      list("Survival / mortality", m_survival), list("Physiology", m_physiology),
                      list("Microbial / fungal biomass", m_micro_biomass))),
  list("HEAT", list(list("Air temperature", m_air_temp), list("Evapotranspiration", m_ET), list("Energy balance", m_energy))),
  list("STORM", list(list("Soil water / hydraulic", m_water_ret))),
  list("BIODIV", list(list("Plant diversity", m_plant_div), list("Microbial / fungal diversity", m_micro), list("Animal / insect", m_animal))),
  list("WELL", list(list("Perceptions / attitudes", m_perception), list("Physical / mental health", m_health),
                    list("Cost", m_cost), list("Education / awareness", m_education))),
  list("OTHER", list(list("Air quality (pollutant/dust)", m_airq), list("Soil nutrients / pH", m_soil_nut), list("Site physical properties", m_site_phys))))
meas_cat <- character(); meas_lab <- character(); meas_fn <- list()
for (g in measurement_groups) for (it in g[[2]]) { meas_cat <- c(meas_cat, g[[1]]); meas_lab <- c(meas_lab, it[[1]]); meas_fn <- c(meas_fn, list(it[[2]])) }
n_meas <- length(meas_lab)

# design-rigor columns (label, key)
rigor_lab <- c("Urban site","Comparison to other vegetation plots","Comparison to other urban greening",
               "Comparison to other urban tree planting","Replicated Mini Forests","Replicated comparison plots",
               "Statistical test vs other urban greening","Statistical test vs other tree planting")
rigor_key <- c("Urban","CV","CG","CU","RM","RC","SG","SP")
n_rig <- length(rigor_key)

# ---- per-paper measurement mask + rigor count -------------------------------
meas_mask <- t(sapply(P$DT, function(s) vapply(meas_fn, function(fn) isTRUE(fn(s)), logical(1))))
colnames(meas_mask) <- NULL

# documented overrides (kept in sync with Figure 2): studies that report plant
# GROWTH only as "stem count" / "plant height" (missed by the keyword rule), plus
# Guo's soil-water ("moisture capacity"). Verified against the verbatim text.
meas_mask[which(P$label == "Ranjan 2016"),     which(meas_lab == "Plant growth / biomass")] <- TRUE
meas_mask[which(P$label == "Schirone 2011"),   which(meas_lab == "Plant growth / biomass")] <- TRUE
meas_mask[which(P$label == "Frattaroli 2017"), which(meas_lab == "Plant growth / biomass")] <- TRUE
meas_mask[which(P$label == "Guo 2018"),        which(meas_lab == "Soil water / hydraulic")] <- TRUE
# 2026-08-20 (JMB): Frattaroli reports plant height and stem count PER SPECIES,
# i.e. it carries plant species data, so it also counts as plant biodiversity.
# Same override as Figure2_evidence_matrix.R / Table S1.
meas_mask[which(P$label == "Frattaroli 2017"), which(meas_lab == "Plant diversity")] <- TRUE

P_bfactors <- rowSums(sapply(rigor_key, function(k) P[[k]] == "Yes" & !is.na(P[[k]])))

# ---- quality categories: peer-review x indexed, best -> worst ---------------
cat_key <- ifelse(P$Pr == "Yes" & !is.na(P$Pr), "PR", "nonPR")
cat_key <- paste0(cat_key, "/", ifelse(P$Idx == "Yes" & !is.na(P$Idx), "idx", "nonidx"))
P$catkey <- cat_key
CATEGORY_ORDER <- list(c("PR/idx","PEER-REVIEWED","Indexed in Scopus / WoS"),
                       c("PR/nonidx","PEER-REVIEWED","Not indexed"),
                       c("nonPR/idx","NOT PEER-REVIEWED","Indexed in Scopus / WoS"),
                       c("nonPR/nonidx","NOT PEER-REVIEWED","Not indexed"))

# within-category sort key (JMB 2026-08-04): SERIATE by column, left to right,
# exactly like Figure 2 — measurement columns present-first (lexicographic across
# the reordered columns), then year, then label. (Was: rigor-count then label.)
meas_sortstr <- apply(meas_mask, 1, function(m) paste(ifelse(m, "0", "1"), collapse = ""))

# ---- assemble display rows (section headers + sorted members) ---------------
disp <- data.frame(is_section = logical(), label = character(), title = character(),
                   sub = character(), n = integer(), P_idx = integer(), stringsAsFactors = FALSE)
for (co in CATEGORY_ORDER) {
  mem <- which(P$catkey == co[1])
  if (!length(mem)) next
  ord <- order(meas_sortstr[mem], P$Year[mem], tolower(P$label[mem]))    # seriate by column, then year, then label
  mem <- mem[ord]
  disp <- rbind(disp, data.frame(is_section = TRUE, label = NA, title = co[2], sub = co[3],
                                 n = length(mem), P_idx = NA, stringsAsFactors = FALSE))
  disp <- rbind(disp, data.frame(is_section = FALSE, label = P$label[mem], title = NA, sub = NA,
                                 n = NA, P_idx = mem, stringsAsFactors = FALSE))
}
disp$row <- seq_len(nrow(disp)) - 1                                   # 0-based row index (row 0 at top)
n_rows <- nrow(disp)
cat(sprintf("Rows: %d studies + %d category headers = %d\n", sum(!disp$is_section), sum(disp$is_section), n_rows))

# ---- VERIFICATION dump: order + masks (compared to python_rows.csv) ---------
dump <- lapply(seq_len(n_rows), function(i) {
  if (disp$is_section[i]) c("SECTION", paste(disp$title[i], "|", disp$sub[i]), disp$n[i], "")
  else { pi <- disp$P_idx[i]
    c("DATA", disp$label[i], paste(ifelse(meas_mask[pi, ], "1", "0"), collapse = ""),
      paste(ifelse(vapply(rigor_key, function(k) isTRUE(P[[k]][pi] == "Yes"), logical(1)), "1", "0"), collapse = "")) }
})
write.table(do.call(rbind, dump), file.path(tempdir(), "r_rows.csv"),
            sep = ",", quote = FALSE, row.names = FALSE, col.names = FALSE)

# =============================================================================
# RENDER
# =============================================================================
# group column spans (for bands + banner)
grp <- data.frame(cat = unique(meas_cat), stringsAsFactors = FALSE)
grp$start <- sapply(grp$cat, function(c) min(which(meas_cat == c)) - 1)     # 0-based first col
grp$end   <- sapply(grp$cat, function(c) max(which(meas_cat == c)) - 1)     # 0-based last col

data_rows <- disp[!disp$is_section, ]
sec_rows  <- disp[disp$is_section, ]

# dot data frames
dotsA <- do.call(rbind, lapply(which(!disp$is_section), function(i) {
  pi <- disp$P_idx[i]
  data.frame(row = disp$row[i], colx = 0:(n_meas - 1), present = meas_mask[pi, ], cat = meas_cat)
}))
dotsB <- do.call(rbind, lapply(which(!disp$is_section), function(i) {
  pi <- disp$P_idx[i]
  data.frame(row = disp$row[i], colx = 0:(n_rig - 1),
             met = vapply(rigor_key, function(k) isTRUE(P[[k]][pi] == "Yes"), logical(1)))
}))
dotsA$fill <- ifelse(dotsA$present, CAT[dotsA$cat], "white")
dotsA$colr <- ifelse(dotsA$present, CAT[dotsA$cat], "#bbbbbb")
stripes <- data_rows[data_rows$row %% 2 == 0, ]
# banner raised (BANNER_BOT more negative) so the enlarged rotated headers clear
# it, and made taller so the long rotated words (BIODIVERSITY) are not clipped.
C_RIGOR <- "#37474F"; BANNER_TOP <- -14.2; BANNER_BOT <- -9.3

# Mini Forest age (years): free text (single year, range, list, or "Unknown").
# 2026-09-07 (JMB): each study's age must sit on ONE LINE. The old strwrap(8) broke
# long lists over up to four lines that overran their own row and collided with the
# neighbouring studies. Missing ages print "----" (JMB's own placeholder in the
# 2026-09-07 Illustrator version) rather than an empty cell.
age_disp_all <- vapply(seq_len(nrow(P)), function(i) {
  a <- trimws(P$Age[i])
  if (tolower(a) %in% c("", "na", "n/a", "none")) "----" else a       # <-- look: one line per study, no wrapping
}, character(1))

# ---- geometry of the two text columns (Data type pill, Mini Forest age) -----
# Widths are MEASURED, not guessed: strwidth() on a Times device at the element's
# point size (a ggplot size in mm is size * 72.27/25.4 pt), converted to x-units
# with IN_PER_UNIT. The age column therefore comes out exactly as wide as its
# longest entry needs, so nothing wraps and nothing overlaps its neighbour.
IN_PER_UNIT <- 0.3774                                                 # inches per x-unit — HELD FIXED so glyphs keep the size they had at 15 in
.tw <- function(txt, size_mm) { pdf(NULL); on.exit(dev.off())
                                par(family = "Times", ps = size_mm * (72.27/25.4))
                                max(strwidth(txt, units = "inches")) }
W_AGE  <- .tw(age_disp_all, SZ_PILL) / IN_PER_UNIT                                  # widest age string, in x-units
W_PILL <- (.tw(c("Quant", "Qual", "Quant + Qual"), SZ_PILL) + 0.07) / IN_PER_UNIT   # + geom_label padding
cat(sprintf("Age column: %.2f x-units wide, set by '%s'\n",
            W_AGE, age_disp_all[which.max(nchar(age_disp_all))]))    # <-- look: one long cell drives the whole column

DT_X    <- n_meas + 0.4 + W_PILL/2                                    # pill column centre, just right of the dot matrix
AGE_X   <- DT_X + W_PILL/2 + 0.55 + W_AGE/2                           # age column centre, clear of the pill
X_RIGHT <- AGE_X + W_AGE/2 + 0.3                                      # right edge of Panel A
PILL_FILL <- c("Quant" = "#404040", "Quant + Qual" = "#8A8A8A", "Qual" = "#BDBDBD")  # Figure 2's two greys + a mid tone for mixed

age_df <- data.frame(row = data_rows$row, lab = age_disp_all[data_rows$P_idx], stringsAsFactors = FALSE)

dt_df <- data.frame(row = data_rows$row, lab = P$DType[data_rows$P_idx], stringsAsFactors = FALSE)
dt_df <- dt_df[nchar(dt_df$lab) > 0, ]                                # blank Data type draws no pill
dt_df$fill <- PILL_FILL[dt_df$lab]

# ---- Panel A ----------------------------------------------------------------
panelA <- ggplot() +
  # category background bands
  geom_rect(data = grp, aes(xmin = start - 0.5, xmax = end + 0.5, ymin = -0.5, ymax = n_rows - 0.5,
                            fill = cat), alpha = CAT_BAND_ALPHA, show.legend = FALSE) +
  scale_fill_manual(values = CAT) +
  # alternating row stripes
  geom_rect(data = stripes, aes(xmin = -0.5, xmax = n_meas - 0.5, ymin = row - 0.5, ymax = row + 0.5),
            fill = "#f3f3f3") +
  # group separators — bounded to the data rows (was geom_vline spanning the whole panel)
  geom_segment(data = data.frame(x = grp$end[-nrow(grp)] + 0.5),
               aes(x = x, xend = x, y = -0.5, yend = n_rows - 0.5), colour = "#cccccc", linewidth = 0.3) +
  # section dividers
  geom_segment(data = sec_rows[sec_rows$row > 0, ], aes(x = -0.5, xend = n_meas - 0.5, y = row - 0.5, yend = row - 0.5),
               colour = "#222222", linewidth = 0.4) +
  # dots (open first, then filled on top)
  geom_point(data = dotsA[!dotsA$present, ], aes(colx, row), shape = 21, fill = "white",
             colour = "#bbbbbb", size = SZ_DOT0, stroke = 0.35) +
  geom_point(data = dotsA[dotsA$present, ], aes(colx, row, fill = I(fill), colour = I(colr)),
             shape = 21, size = SZ_DOT, stroke = 0.4) +
  # row labels (paper short-cites)
  geom_text(data = data_rows, aes(-0.85, row, label = label), hjust = 1, size = SZ_ROW, colour = "#222222") +
  # section header labels: bold title above, sub/n below. Both CENTRE-anchored
  # (vjust 0.5) and offset symmetrically so the two lines never collide.
  geom_text(data = sec_rows, aes(-0.85, row - 0.24, label = title), hjust = 1, vjust = 0.5,
            fontface = "bold", size = SZ_SEC_T, colour = "#222222") +
  geom_text(data = sec_rows, aes(-0.85, row + 0.22, label = sprintf("%s  ·  n = %d", sub, n)),
            hjust = 1, vjust = 0.5, size = SZ_SEC_S, colour = "#444444") +
  # rotated column headers (single line, bottom-anchored just above the data)
  geom_text(data = data.frame(colx = 0:(n_meas - 1), lab = meas_lab),
            aes(colx, -0.7, label = lab), angle = 90, hjust = 0, vjust = 0.5, size = SZ_COLA, colour = "#222222") +
  # Data type pill (Quant / Qual / both) + its rotated header
  geom_label(data = dt_df, aes(DT_X, row, label = lab, fill = I(fill)), colour = "white", size = SZ_PILL,
             label.r = unit(0.12, "lines"), label.padding = unit(0.20, "lines"), linewidth = 0) +
  annotate("text", x = DT_X, y = -0.7, label = "Data type", angle = 90, hjust = 0, vjust = 0.5,
           size = SZ_COLA, colour = "#222222") +
  # Mini Forest age (years) text column + its rotated header
  geom_text(data = age_df, aes(AGE_X, row, label = lab), size = SZ_PILL, lineheight = 0.82, colour = "#222222") +
  annotate("text", x = AGE_X, y = -0.7, label = "Mini Forest age (years)", angle = 90, hjust = 0, vjust = 0.5,
           size = SZ_COLA, colour = "#222222") +
  # category banner (coloured rects + vertical white labels)
  geom_rect(data = grp, aes(xmin = start - 0.5, xmax = end + 0.5, ymin = BANNER_TOP, ymax = BANNER_BOT, fill = cat),
            alpha = 0.92, show.legend = FALSE) +
  geom_text(data = grp, aes((start + end) / 2, (BANNER_TOP + BANNER_BOT) / 2, label = cat_band_label[cat]),
            angle = 90, colour = "white", fontface = "bold", size = SZ_BANNER) +
  coord_cartesian(xlim = c(-9, X_RIGHT), ylim = c(n_rows - 0.5, BANNER_TOP - 0.5), clip = "off") +
  scale_y_reverse() +
  guides(fill = "none") +                                            # suppress the auto fill legend for `cat`
  theme_void(base_family = .FIGFONT) + theme(legend.position = "none")

# ---- Panel B ----------------------------------------------------------------
panelB <- ggplot() +
  geom_rect(data = stripes, aes(xmin = -0.5, xmax = n_rig - 0.5, ymin = row - 0.5, ymax = row + 0.5),
            fill = "#f3f3f3") +
  geom_segment(data = sec_rows[sec_rows$row > 0, ], aes(x = -0.5, xend = n_rig - 0.5, y = row - 0.5, yend = row - 0.5),
               colour = "#222222", linewidth = 0.4) +
  geom_point(data = dotsB[!dotsB$met, ], aes(colx, row), shape = 21, fill = "white",
             colour = "#bbbbbb", size = SZ_DOT0, stroke = 0.35) +
  geom_point(data = dotsB[dotsB$met, ], aes(colx, row), shape = 21, fill = C_RIGOR,
             colour = C_RIGOR, size = SZ_DOT, stroke = 0.4) +
  # rotated column headers (single line, bottom-anchored to match Panel A)
  geom_text(data = data.frame(colx = 0:(n_rig - 1), lab = rigor_lab),
            aes(colx, -0.7, label = lab), angle = 90, hjust = 0, vjust = 0.5, fontface = "bold", size = SZ_COLB,
            colour = "#222222") +
  coord_cartesian(xlim = c(-0.5, n_rig - 0.5), ylim = c(n_rows - 0.5, BANNER_TOP - 0.5), clip = "off") +
  scale_y_reverse() +
  theme_void(base_family = .FIGFONT)

# ---- legend strip (present / absent), built as its own tiny plot ------------
legend_plot <- ggplot() +
  geom_point(aes(0, 1), shape = 21, fill = C_RIGOR, colour = C_RIGOR, size = SZ_DOT + 0.4) +
  annotate("text", x = 0.05, y = 1, label = "Present / criterion met", hjust = 0, size = 4.2) +
  geom_point(aes(2.4, 1), shape = 21, fill = "white", colour = "#bbbbbb", size = SZ_DOT0 + 0.3) +
  annotate("text", x = 2.45, y = 1, label = "Absent / not met", hjust = 0, size = 4.2) +
  coord_cartesian(xlim = c(-0.1, 5), ylim = c(0.5, 1.5), clip = "off") + theme_void(base_family = .FIGFONT)

# ---- compose: A | B over a thin legend row ----------------------------------
# Panel widths are set to each panel's x-unit span (A = labels + n_meas + age;
# B = n_rig) so the dot spacing is UNIFORM across both panels — this fixes the
# previously over-wide, sparse rigor panel. Canvas shrunk from 22.2x26 so the
# text reads at a sensible size and the figure carries far less white space.
# widths = each panel's x-unit span (A = 9 units of labels + the matrix + the two
# text columns; B = n_rig), so the dot pitch is identical in both panels.
fig <- (panelA + panelB + plot_layout(widths = c(9 + X_RIGHT, n_rig))) / legend_plot +
  plot_layout(heights = c(26, 0.7))
# Canvas width follows the panel spans at a FIXED inches-per-x-unit, so adding the
# Data type pill (2026-09-07) and widening the age column to fit one-line entries
# grows the figure instead of shrinking every glyph on it.
FIG_W <- round(IN_PER_UNIT * (9 + X_RIGHT + n_rig), 1); FIG_H <- 24
cat(sprintf("Canvas: %.1f x %.1f in\n", FIG_W, FIG_H))

# base pdf device can't resolve "Times New Roman"; alias it to the built-in Times
# Type1 metrics (cairo_pdf is unavailable on this machine). PNG/SVG use true TNR.
grDevices::pdfFonts("Times New Roman" = grDevices::pdfFonts()$Times)
for (stem in c("Mini_Forest_combined_evidence_figure", "FigureS1_Mini_Forest_combined_evidence_figure")) {
  ggsave(file.path(OUTDIR, paste0(stem, ".pdf")), fig, width = FIG_W, height = FIG_H, device = "pdf", limitsize = FALSE)
  if (requireNamespace("svglite", quietly = TRUE))
    ggsave(file.path(OUTDIR, paste0(stem, ".svg")), fig, width = FIG_W, height = FIG_H, limitsize = FALSE)
  ggsave(file.path(OUTDIR, paste0(stem, ".png")), fig, width = FIG_W, height = FIG_H, dpi = 150, limitsize = FALSE,
         device = if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else "png")
  cat(sprintf("Saved: %s/%s.{pdf,svg,png}\n", OUTDIR, stem))
}

# ---- console summary --------------------------------------------------------
for (co in CATEGORY_ORDER) { m <- sum(P$catkey == co[1]); if (m) cat(sprintf("  %s / %s: n=%d\n", co[2], co[3], m)) }

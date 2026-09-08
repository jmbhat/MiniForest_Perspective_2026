# ============================================================================
# Figure 2 — Evidence matrix for peer-reviewed, Scopus/WoS-INDEXED articles
#            presenting EMPIRICAL data on Mini Forests
#
# Source : Mini_Forest_academic_corpus.xlsx, sheet 'Paper_analysis'
# Filters: Peer reviewed = Yes; Index (SC/WOS) = Yes;
#          Empirical data on Miyawaki forest = Yes
#
# 2026-07-30: rebuilt to READ THE WORKBOOK DIRECTLY instead of a hard-coded
# 9-row table. The refreshed spreadsheet yields n = 19 studies matching the
# filter. Study rows, the Quant/Qual data-type pill, the four study-design
# columns, the measurement text and the Result text are all pulled from their
# cells (blank cells left blank on the figure).
#
# 2026-08-03 revision (this file) — formatting overhaul requested by JMB:
#   * FONT: Times New Roman throughout, and much larger than before.
#   * ROTATED COLUMN HEADERS now BOTTOM-anchored (bottoms aligned on a common
#     baseline just above the data, growing UPWARD toward the banner) instead of
#     top-anchored/hanging-down.
#   * ROW ORDER is by ECOSYSTEM-SERVICE PRIORITY, not year: a study goes in the
#     Carbon block if it has ANY Carbon dot; else Heat; else Stormwater; else
#     Biodiversity; else Well-being. Within a block, chronological. (Carbon top,
#     Well-being bottom.)
#   * "Type of data described" is pulled from the 'Measurements' column and
#     "Result" from the 'Results' column, but BOTH are shown as CONDENSED 1-2
#     line versions (lookup tables .TEXT_DISP / .RES_DISP below) so cells stay
#     small and the figure does not blow up. The condensed text is display-only:
#     the measurement DOTS are still derived from the VERBATIM 'Measurements'
#     text, so the matrix is unchanged. A verbatim-vs-condensed review table is
#     printed to the console and written to a CSV — read it before trusting the
#     figure.
#
# 2026-08-20 revision (JMB):
#   * FIGURE IS NOW URBAN SITES ONLY. The 'In urban area?' filter is applied, so
#     Ranjan 2016, Schirone 2011 and Frattaroli 2017 drop out (19 -> 16 studies)
#     and the "Urban site" column is removed from the figure (every row is urban).
#   * "Type of data described" and "Result" MOVED OUT of the figure into
#     Table S1 (see TableS1_evidence_text.R). Row heights no longer depend on
#     wrapped text, so every row is now a uniform ROW_H tall and the figure is
#     far narrower.
#   * Frattaroli 2017 gains a plant-diversity assignment (it reports stem count
#     and height PER SPECIES). Frattaroli is non-urban so this is visible only in
#     Table S1, but the assignment is made here so both outputs agree.
#   * Service assignments for ALL 19 studies (before the urban filter) are
#     written to Figure2_service_assignments.csv, which TableS1_evidence_text.R
#     reads. RUN THIS SCRIPT FIRST, THEN the Table S1 script.
#
# Service categories are split into MEASUREMENT SUBCOLUMNS, assigned with the
# SAME keyword rule as Figure S1 applied to the verbatim 'Measurements' field.
# Only the 10 curated subcolumns are drawn; two documented overrides patch known
# keyword-rule gaps (Ranjan growth, Guo water).
# ============================================================================

library(tidyverse)
library(readxl)

# ---- font ------------------------------------------------------------------
# Times New Roman throughout (verified present via systemfonts::system_fonts()).
.FIGFONT <- "Times New Roman"
theme_set(theme_void(base_family = .FIGFONT))
update_geom_defaults("text",  list(family = .FIGFONT))
update_geom_defaults("label", list(family = .FIGFONT))

# ---- font SIZES (bumped up ~35-45% vs the prior figure) --------------------
SZ_ROWLAB <- 6.6   # study row labels (Surname Year)
SZ_CELL   <- 4.1   # "Type of data described" + "Result" cell text
SZ_ROTLAB <- 5.4   # rotated sub/design column labels (single line each)
SZ_COLHDR <- 6.0   # horizontal "Type of data described" / "Result" headers
SZ_BANNER <- 5.0   # rotated CARBON/HEAT/... banner labels
SZ_GRPTTL <- 6.6   # "Ecosystem service addressed" / "Study design..." titles
SZ_PILL   <- 4.2   # Quant/Qual data-type pill
SZ_LEGEND <- 4.4   # legend text
DOT_SZ    <- 6.6   # glyph diameter (kept close to prior 6)

# ---- palette ---------------------------------------------------------------
CAT <- c(Carbon="#2E7D32", Heat="#E65100", Storm="#0277BD",
         Biodiv="#7E57C2", Well="#00897B")
CAT_LABEL <- c(Carbon="CARBON", Heat="HEAT", Storm="STORMWATER",
               Biodiv="BIODIVERSITY", Well="WELL-BEING")
DARK<-"#222222"; GREY<-"#9a9a9a"; CHARC<-"#37474F"

# ---- 1. read the source spreadsheet & derive the study rows ----------------
XLSX <- "data/Mini_Forest_academic_corpus.xlsx"
raw  <- read_excel(XLSX, sheet = "Paper_analysis", .name_repair = "minimal")
hdr  <- tolower(trimws(names(raw)))

gcol <- function(...) {                              # column accessor by header
  for (o in tolower(c(...))) { i <- which(startsWith(hdr, o)); if (length(i)) return(raw[[i[1]]]) }
  for (o in tolower(c(...))) { i <- which(grepl(o, hdr, fixed = TRUE)); if (length(i)) return(raw[[i[1]]]) }
  stop("column not found: ", paste(c(...), collapse = " / "))
}
yn <- function(v) {                                  # -> "yes" / "no" / ""
  s <- tolower(trimws(ifelse(is.na(v), "", as.character(v))))
  ifelse(startsWith(s, "yes"), "yes", ifelse(startsWith(s, "no"), "no", ""))
}
chr <- function(v) trimws(ifelse(is.na(v), "", as.character(v)))
surname <- function(a) {                             # first-author surname
  a1 <- trimws(strsplit(chr(a), ";", fixed = TRUE)[[1]][1])
  if (grepl(",", a1, fixed = TRUE)) return(trimws(sub(",.*$", "", a1)))   # "Guo, X.F." -> Guo
  toks <- strsplit(a1, "\\s+")[[1]]                                       # "Qi H."     -> Qi
  keep <- toks[!grepl("^[A-Z]([.-][A-Z]?)*\\.?$", toks)]
  if (length(keep)) paste(keep, collapse = " ") else a1
}

.year_num <- as.integer(sub(".*?(\\d{4}).*", "\\1", chr(gcol("Year"))))

# design-rigor columns pulled verbatim (yes/no) from the workbook. 2026-08-04:
# expanded from 4 to the full 7 study-design criteria requested by JMB.
papers <- tibble(
  auth   = gcol("Authors"),
  yr     = .year_num,
  idx    = yn(gcol("Index")),
  emp    = yn(gcol("Empirical data on Miyawaki")),
  pr     = yn(gcol("Peer reviewed")),
  urban  = yn(gcol("In urban area")) == "yes",
  dtraw  = tolower(chr(gcol("Data type"))),
  text   = chr(gcol("Measurements")),                 # VERBATIM measurements (drives dots)
  cv     = yn(gcol("Comparison to other types of vegetation")),
  cu     = yn(gcol("Comparison to other types of urban tree planting")),
  rm     = yn(gcol("Replicated Miyawaki")),
  rc     = yn(gcol("Replicated Comparison")),
  sp     = yn(gcol("Statistical tests of claim against other types of urban tree planting")),
  age    = chr(gcol("Miyawaki forest age")),          # Mini Forest age (years) — free text (may be a list/range/"Unknown")
  result = chr(gcol("Results"))                       # VERBATIM result text
) %>%
  filter(!is.na(auth), pr == "yes", idx == "yes", emp == "yes") %>%
  mutate(
    label = paste(vapply(auth, surname, character(1)),
                  ifelse(is.na(yr), "n.d.", as.character(yr))),
    dtype = case_when(startsWith(dtraw, "quant") ~ "Quant",
                      startsWith(dtraw, "qual")  ~ "Qual",
                      TRUE ~ "")                        # blank Data-type left blank
  )

# ---- 1b. Mini Forest age display text --------------------------------------
papers <- papers %>%
  mutate(age_disp = ifelse(tolower(trimws(age)) %in% c("", "na", "n/a", "none"), "",
                           str_wrap(age, 8)))          # blank literal "NA"; wrap long lists (e.g. "1, 3, 5, 7, 9, 11")

# ---- 2. service subcolumns + presence matrix (1 = measured) -----------------
# Column order (JMB 2026-08-04): Soil C / SOM moved up to sit 2nd, right after
# Plant C stocks / sequestration; the rest follow. All five carbon columns stay
# contiguous under the CARBON band.
subcols <- tribble(
  ~key,        ~cat,     ~lab,
  "Cstock",    "Carbon", "Plant C stocks / sequestration",
  "soilC",     "Carbon", "Soil C / SOM",
  "growth",    "Carbon", "Plant growth / biomass",
  "survival",  "Carbon", "Survival / mortality",
  "heat",      "Heat",   "Air temp / ET / energy balance",
  "water",     "Storm",  "Soil water / hydraulic",
  "plantdiv",  "Biodiv", "Plant diversity",
  "animal",    "Biodiv", "Animal / insect",
  "perception","Well",   "Perceptions / attitudes"
) %>% mutate(j = row_number() - 1)   # 2026-08-04: "Canopy cover" removed (JMB)

# presence matrix derived from the verbatim 'Measurements' text (SAME keyword
# rule Figure S1 uses).
has_any <- function(s, kws) any(vapply(kws, function(k) grepl(k, s, fixed = TRUE), logical(1)))
matchers <- list(
  Cstock   = function(s) has_any(s, c("carbon stock","c stock","sequestration","c sequestration","carbon sequest","tissue","carbon concentration")),
  growth   = function(s) { for (ph in c("soil microbial biomass","microbial biomass","bacterial biomass","fungal biomass")) s <- gsub(ph, "", s, fixed = TRUE)
                           has_any(s, c("growth rate","growth rates","growth ","dbh","flowering","fruiting","plant biomass","tree biomass","biomass")) },
  survival = function(s) has_any(s, c("mortality","survival")),
  canopy   = function(s) has_any(s, c("canopy","plant cover","vegetation cover")),
  soilC    = function(s) has_any(s, c("som content","som,","soil organic","soil c ","soil %organic","organic carbon","soil carbon")) ||
                         (grepl("soil", s, fixed = TRUE) && grepl("carbon concentration", s, fixed = TRUE)),
  heat     = function(s) grepl("\\bair\\s+temp", s) ||
                         (grepl("temperature", s, fixed = TRUE) && grepl("soil temperature", s, fixed = TRUE)) ||
                         grepl("thermal", s, fixed = TRUE) ||
                         has_any(s, c("evapotrans","water vapor","transpiration rate","energy balance")),
  water    = function(s) has_any(s, c("water retention","hydraulic")),
  plantdiv = function(s) has_any(s, c("plant diversity","species diversity","plant species diversity","community composition")),
  animal   = function(s) has_any(s, c("insect","pollinator","animal")),
  perception = function(s) has_any(s, c("perception","perceived","feeling","thought","attitude","opinion","awareness",
                                        "knowledge","understanding","expectation","experience","sense ","senses ","ownership",
                                        "place attachment","pride","concern","important elements","discourse","favorability",
                                        "favourability","acceptance","success or failure"))
)
presence <- t(vapply(tolower(papers$text),
                     function(s) vapply(subcols$key, function(k) as.integer(matchers[[k]](s)), integer(1)),
                     integer(nrow(subcols))))
dimnames(presence) <- NULL

# documented overrides — keyword rule misses a measurement the study reports.
# (The 2026-08-03 workbook rewrote several 'Measurements' cells more tersely, so
# a few studies that clearly measure plant GROWTH now describe it only as
# "stem count" / "plant height" — growth metrics the keyword rule does not catch.
# These overrides restore those growth dots. NOTE: the rewritten cells also
# dropped explicit "plant diversity" wording for Schirone & Frattaroli, so those
# plant-diversity dots are intentionally NOT restored — the figure now follows
# the workbook's more precise text. Flag any of these you disagree with.)
presence[which(papers$label == "Ranjan 2016"),   which(subcols$key == "growth")] <- 1L  # "Survival rate, average plant height ... over time"
presence[which(papers$label == "Guo 2018"),      which(subcols$key == "water")]  <- 1L  # "soil ... % moisture, moisture capacity"
presence[which(papers$label == "Schirone 2011"), which(subcols$key == "growth")] <- 1L  # "stem count and average height of individual plant species"
presence[which(papers$label == "Frattaroli 2017"),which(subcols$key == "growth")] <- 1L  # "Average plant height, stem count per species"
# 2026-08-20 (JMB): Frattaroli reports plant height and stem count PER SPECIES,
# i.e. it carries plant species data, so it counts as plant biodiversity.
presence[which(papers$label == "Frattaroli 2017"),which(subcols$key == "plantdiv")] <- 1L

# ---- 2b. row ordering: SERIATE by column, left to right --------------------
# Row order (JMB 2026-08-04): order rows BY COLUMN, starting at the left. A study
# with a dot in the leftmost service column (Plant C stocks / sequestration)
# sorts to the top; ties fall to the next column (Soil C / SOM), then Plant
# growth / biomass, and so on across all 10 service columns (present sorts before
# absent). Ties within an identical dot pattern fall back to year, then label.
# This replaces the earlier primary-category blocking; primcat is still computed
# below purely as an informational field in the verification table.
.cat_order <- c("Carbon","Heat","Storm","Biodiv","Well")
.cat_cols  <- lapply(.cat_order, function(cc) which(subcols$cat == cc))
names(.cat_cols) <- .cat_order
primcat <- vapply(seq_len(nrow(papers)), function(i) {
  hit <- .cat_order[vapply(.cat_order, function(cc) any(presence[i, .cat_cols[[cc]]] == 1L), logical(1))]
  if (length(hit)) hit[1] else "Well"        # no dot at all -> Well-being
}, character(1))
papers$primcat <- primcat

# seriation key: for each row, "0" where a dot is present (sorts first), "1" where
# absent, read left -> right across subcols in their (reordered) display order.
meas_key <- apply(presence, 1, function(r) paste(ifelse(r == 1, "0", "1"), collapse = ""))
ord <- order(meas_key, papers$yr, papers$label)
papers   <- papers[ord, ]
presence <- presence[ord, , drop = FALSE]
papers$row <- seq_len(nrow(papers))

# ---- 2c. SERVICE ASSIGNMENTS for all 19 studies -> Table S1 -----------------
# Written BEFORE the urban filter so Table S1 can cover every peer-reviewed,
# indexed, empirical study (including the three non-urban ones the figure drops).
.svc_of_cat <- c(Carbon="Carbon", Heat="Heat", Storm="Stormwater",
                 Biodiv="Biodiversity", Well="Well-being")
assignments <- tibble(
  label     = papers$label,
  year      = papers$yr,
  urban     = ifelse(papers$urban, "Yes", "No"),
  dtype     = papers$dtype,
  measures  = apply(presence, 1, function(r) paste(subcols$lab[r == 1], collapse = "; ")),
  services  = apply(presence, 1, function(r)
                paste(unique(.svc_of_cat[subcols$cat[r == 1]]), collapse = "; ")),
  # verbatim workbook cells travel with the labels so the Table S1 script never
  # has to re-derive "Surname Year" from the Authors column (that collapses
  # different papers onto the same key).
  measurements_verbatim = papers$text,
  results_verbatim      = papers$result
)
write_csv(assignments, "Figure2_service_assignments.csv")
message(sprintf("Service assignments for %d studies -> Figure2_service_assignments.csv", nrow(assignments)))

# ---- 2d. URBAN SITES ONLY (JMB 2026-08-20) ---------------------------------
.n_all   <- nrow(papers)
.keep    <- which(papers$urban)
papers   <- papers[.keep, ]
presence <- presence[.keep, , drop = FALSE]
papers$row <- seq_len(nrow(papers))                       # renumber 1..16 for the row stripes
message(sprintf("Urban-only filter: %d of %d studies kept", nrow(papers), .n_all))


# ---- uniform row geometry (JMB 2026-08-20) ---------------------------------
# The two long text columns moved to Table S1, so nothing forces a row to be
# tall any more: every row is the same height and the matrix reads as a grid.
ROW_H <- 1.05                                                # row height in y-units
papers$rh   <- ROW_H
papers$y    <- (nrow(papers) - papers$row) * ROW_H + ROW_H/2  # row 1 highest
papers$ymin <- papers$y - ROW_H/2
papers$ymax <- papers$y + ROW_H/2

# ---- 3. geometry -----------------------------------------------------------
STEP<-0.7; x_serv0<-0.6      # 2026-08-20: pulled left, the 'Urban site' column at x=0 is gone
xsub <- function(j) x_serv0 + j*STEP
x_dtype  <- xsub(nrow(subcols)-1) + 1.6
x_age    <- x_dtype + 1.5                 # Mini Forest age (years) text column
x_des0   <- x_age + 1.6
# 2026-08-20: the design labels are WRAPPED TO 2 LINES. Single-line labels (up to
# 69 characters) were fine on the old 21-inch-wide figure, but with the two text
# columns gone they would stand taller than the whole data block. Wrapping halves
# the header height; DES_STEP widens these columns to hold the second line.
DES_STEP <- 1.30
design_cols <- tribble(~key,~lab,
  "cv","Comparison to other types of vegetation plots",
  "cu","Comparison to other types of urban tree planting",
  "rm","Replicated Mini Forests",
  "rc","Replicated comparison plots",
  "sp","Statistical tests of claim against other types of urban tree planting") %>%
  mutate(k = row_number() - 1, lab_wrap = str_wrap(lab, 34))
xdes <- function(k) x_des0 + k*DES_STEP
x_right  <- xdes(nrow(design_cols)-1) + 0.4      # right edge of the drawn matrix
band_lo <- min(papers$ymin); band_hi <- max(papers$ymax)   # data-row vertical extent
top <- band_hi + 0.4

# ---- 5. banners ------------------------------------------------------------
# Rotated column labels are now SINGLE-LINE and BOTTOM-anchored: their bottoms
# sit on the baseline hb_bot (just above the data) and grow UPWARD (hjust = 0).
# Single-line labels are taller than the old 2-line ones, so the coloured banner
# and the group-title band are RAISED to clear them. Each label's vertical
# extent is estimated from its character count (Times ~0.52 em/char) on the
# aspect-matched canvas, so the layout adapts if font sizes or labels change.
spans <- subcols %>% group_by(cat) %>%
  summarise(s=min(j), e=max(j), .groups="drop") %>%
  mutate(xmin=xsub(s)-0.33, xmax=xsub(e)+0.33,
         lab=CAT_LABEL[cat], fill=CAT[cat])

# plot X bounds (fixed; independent of the vertical layout)
FIG_W <- 11.6                                              # 2026-08-20: narrower - three columns removed
x_lo <- -4.6; x_hi <- x_right + 1.2
.in_per_unit <- FIG_W / (x_hi - x_lo)                       # coord_fixed(ratio=1) => same on Y
# ~0.50 em/char advance (Times, mixed case) calibrated against the rendered PNG,
# with headroom so the longest label cannot touch the banner above it.
.lab_h <- function(strs, sz)
  max(nchar(unlist(strsplit(strs, "\n", fixed = TRUE)))) * 0.50 * (sz * 2.845) / 72.27 / .in_per_unit

hb_bot  <- top + 0.45                                       # common BOTTOM baseline of rotated labels
eco_top <- hb_bot + .lab_h(subcols$lab,     SZ_ROTLAB)      # top of the tallest service sub-column label
des_top <- hb_bot + .lab_h(design_cols$lab_wrap, SZ_ROTLAB)      # top of the tallest design label (now much taller)

# The 7 design labels (single-line, up to ~69 chars) are far taller than the
# service labels, so the two group headers are DECOUPLED: the coloured banner
# sits just above the service labels; the "Study design" underline sits just
# above the (much taller) design labels. Each group title rides above its own.
BANNER_H <- max(nchar(CAT_LABEL)) * 0.72 * (SZ_BANNER * 2.845) / 72.27 / .in_per_unit + 0.5  # fits "BIODIVERSITY"
ban_y0   <- eco_top + 0.30                                  # banner bottom (just above service labels)
ban_y1   <- ban_y0 + BANNER_H                              # banner top
des_line <- des_top + 0.40                                  # "Study design" underline (above design labels)

# plot Y bounds (aspect-matched canvas, see section 8)
y_lo <- -2.4; y_hi <- max(ban_y1, des_line) + 1.4

# ---- 4. long-format glyph tables -------------------------------------------
serv_glyphs <- expand_grid(ri = seq_len(nrow(papers)), ci = seq_len(nrow(subcols))) %>%
  mutate(x = xsub(subcols$j[ci]), y = papers$y[ri],
         present = presence[cbind(ri,ci)] == 1,
         cat = subcols$cat[ci],
         fill = ifelse(present, CAT[cat], "white"),
         col  = ifelse(present, CAT[cat], GREY))
des_glyphs <- design_cols %>% rowwise() %>%
  do(tibble(x = xdes(.$k), key = .$key)) %>% ungroup() %>%
  crossing(papers %>% select(y, row)) %>%
  left_join(papers %>% select(row, cv, cu, rm, rc, sp), by="row") %>%
  mutate(val = case_when(key=="cv"~cv, key=="cu"~cu, key=="rm"~rm, key=="rc"~rc, TRUE~sp),
         present = val=="yes",
         fill = ifelse(present, CHARC, "white"),
         col  = ifelse(present, CHARC, GREY))

# ---- 6. plot ---------------------------------------------------------------
p <- ggplot() +
  geom_rect(data=papers %>% filter(row %% 2 == 1),
            aes(xmin=-0.6, xmax=x_right, ymin=ymin, ymax=ymax), fill="#f4f4f4") +
  geom_rect(data=spans, aes(xmin=xsub(s)-0.35, xmax=xsub(e)+0.35, ymin=band_lo, ymax=band_hi,
            fill=I(fill)), alpha=0.10) +
  # glyphs
  geom_point(data=serv_glyphs, aes(x,y,fill=I(fill),color=I(col)), shape=21, size=DOT_SZ, stroke=0.9) +
  geom_point(data=des_glyphs,  aes(x,y,fill=I(fill),color=I(col)), shape=21, size=DOT_SZ, stroke=0.9) +
  # data-type pills (blank 'Data type' cells draw no pill)
  geom_label(data=papers %>% filter(dtype != ""), aes(x_dtype, y, label=dtype,
             fill=I(ifelse(dtype=="Quant","#404040","#bdbdbd"))),
             color="white", size=SZ_PILL, label.r=unit(0.12,"lines"), label.padding=unit(0.22,"lines")) +
  # Mini Forest age (years) — verbatim text (may be a single year, range, or list)
  geom_text(data=papers %>% filter(nchar(age_disp) > 0), aes(x_age, y, label=age_disp),
            hjust=0.5, size=SZ_PILL, lineheight=0.9, color=DARK) +
  # row labels
  geom_text(data=papers, aes(-0.75, y, label=label), hjust=1, size=SZ_ROWLAB) +
  # rotated column labels — BOTTOM-anchored, grow UPWARD from hb_bot (hjust=0)
  geom_text(data=subcols, aes(xsub(j), hb_bot, label=lab), angle=90, hjust=0, vjust=0.5, size=SZ_ROTLAB, color=DARK) +
  geom_text(data=design_cols, aes(xdes(k), hb_bot, label=lab_wrap), angle=90, hjust=0, vjust=0.5, size=SZ_ROTLAB, color=DARK) +
  annotate("text", x=x_dtype, y=hb_bot, label="Data type", angle=90, hjust=0, vjust=0.5, size=SZ_ROTLAB) +
  annotate("text", x=x_age, y=hb_bot, label="Mini Forest age (years)", angle=90, hjust=0, vjust=0.5, size=SZ_ROTLAB) +
  # category banners
  geom_rect(data=spans, aes(xmin=xmin, xmax=xmax, ymin=ban_y0, ymax=ban_y1, fill=I(fill))) +
  geom_text(data=spans, aes((xmin+xmax)/2, (ban_y0+ban_y1)/2, label=lab),
            angle=90, color="white", fontface="bold", size=SZ_BANNER) +
  # group titles — each rides just above ITS OWN labels (decoupled heights)
  annotate("text", x=(min(spans$xmin)+max(spans$xmax))/2, y=ban_y1+0.20, label="Ecosystem service addressed",
           hjust=0.5, vjust=0, fontface="bold", size=SZ_GRPTTL, color=DARK) +
  annotate("segment", x=xdes(0)-0.33, xend=xdes(nrow(design_cols)-1)+0.33, y=des_line, yend=des_line,
           color=CHARC, linewidth=1.0) +
  annotate("text", x=mean(xdes(design_cols$k)), y=des_line+0.20, label="Study design / evidence quality",
           hjust=0.5, vjust=0, fontface="bold", size=SZ_GRPTTL, color=CHARC) +
  # legend
  annotate("point", x=-0.4, y=-1.6, shape=21, size=DOT_SZ, fill=DARK, color=DARK) +
  annotate("text",  x=0.0,  y=-1.6, label="Yes / present / addressed", hjust=0, size=SZ_LEGEND) +
  annotate("point", x=4.6,  y=-1.6, shape=21, size=DOT_SZ, fill="white", color=GREY) +
  annotate("text",  x=5.0,  y=-1.6, label="No / absent / not addressed", hjust=0, size=SZ_LEGEND) +
  coord_fixed(ratio=1, xlim=c(x_lo, x_hi), ylim=c(y_lo, y_hi)) +
  theme_void(base_family=.FIGFONT) +
  theme(plot.background = element_rect(fill="white", color=NA),
        plot.margin     = margin(6, 6, 6, 6))

# ---- 7. verification printout (read before trusting the figure) ------------
verify <- papers %>%
  transmute(row, label, primcat, year = yr,
            dtype = ifelse(dtype == "", "(blank)", dtype), age,
            cv, cu, rm, rc, sp,
            services = apply(presence, 1, function(r) paste(subcols$key[r == 1], collapse = ", ")))
message(sprintf("Figure 2: %d studies (peer-reviewed, indexed, empirical)", nrow(papers)))
message("Row order / primary category / measurement dots:")
print(as.data.frame(verify), right = FALSE)

# ---- 8. save (canvas aspect-matched to the data) ---------------------------
# This machine's cairo/X11 libraries are missing, so cairo_pdf is unavailable.
# ragg (PNG) and svglite (SVG) render true Times New Roman via systemfonts and
# are the masters. For the PDF we register a base-R font ALIAS so the family
# name "Times New Roman" resolves to the built-in Times Type1 metrics — a
# visually identical serif with real, selectable text (label reads "Times").
FIG_H <- FIG_W * (y_hi - y_lo) / (x_hi - x_lo)   # FIG_W set in the geometry section
OUT   <- "Figure2_Mini_Forest_evidence_matrix"

# PNG — ragg renders cleanly without cairo/X11 (true Times New Roman).
tryCatch(
  ggsave(paste0(OUT, ".png"), p, width=FIG_W, height=FIG_H, dpi=200, device=ragg::agg_png, limitsize=FALSE),
  error = function(e) message("PNG save failed: ", conditionMessage(e)))
# SVG — svglite gives selectable vector text without cairo (true Times New Roman).
tryCatch(
  ggsave(paste0(OUT, ".svg"), p, width=FIG_W, height=FIG_H, device=svglite::svglite, limitsize=FALSE),
  error = function(e) message("SVG save failed: ", conditionMessage(e)))
# PDF — cairo_pdf if available; else base pdf with the Times New Roman -> Times alias.
tryCatch(
  ggsave(paste0(OUT, ".pdf"), p, width=FIG_W, height=FIG_H, device=cairo_pdf, limitsize=FALSE),
  error = function(e) {
    message("cairo_pdf unavailable (", conditionMessage(e), ") — using base pdf with Times alias")
    grDevices::pdfFonts("Times New Roman" = grDevices::pdfFonts()$Times)
    ggsave(paste0(OUT, ".pdf"), p, width=FIG_W, height=FIG_H, device="pdf", limitsize=FALSE)
  })
message(sprintf("Figure 2 written (PDF, SVG, PNG) — %.1f x %.1f in", FIG_W, FIG_H))

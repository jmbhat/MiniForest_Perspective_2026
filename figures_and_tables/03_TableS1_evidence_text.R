################################################################################
# TableS1_evidence_text.R
#
# TABLE S1 - what each empirical Mini Forest study measured and what it found.
#
# These are the two columns ("Type of data described", "What was found?") that
# used to sit on the right-hand side of Figure 2. Figure 2 is now urban sites
# only; this table keeps ALL 19 peer-reviewed, Scopus/WoS-indexed studies with
# empirical data, so the three non-urban studies (Schirone 2011, Ranjan 2016,
# Frattaroli 2017) are still reported.
#
# RUN Figure2_evidence_matrix.R FIRST - it writes
# Figure2_service_assignments.csv, which
# supplies the ecosystem-service assignments and the row order used here, so the
# table and the figure can never disagree.
#
# Table out: TableS1_evidence_text.docx
#            (Times New Roman, ready to paste into the supplement)
#
# Run one STEP at a time and look at the objects flagged with "# <-- look:".
################################################################################


################################################################################
# STEP 1 - Packages
################################################################################

library(readr)                                                                   # read the service-assignment CSV
library(flextable)                                                               # the Word table itself
library(officer)                                                                 # the .docx wrapper around it


################################################################################
# STEP 2 - Read the service assignments written by Figure2_evidence_matrix.R
################################################################################

assign <- read_csv("Figure2_service_assignments.csv",
                   show_col_types = FALSE)                                       # 19 studies, already in Figure 2 row order
nrow(assign)                                                                     # <-- look: 19 studies (Figure 2 draws the 16 urban ones)
assign                                                                           # <-- look: Frattaroli 2017 should read "Carbon; Biodiversity"


################################################################################
# STEP 3 - "Type of data described", exactly as JMB edited it on the figure
#          Keyed by study label ("Surname Year"). Edit the wording HERE.
################################################################################

described <- c(
  "Goveanthan 2025"    = "Soil organic C, bulk density, porosity, pH; transpiration, photosynthesis, biomass, growth",
  "Sugumaran 2026"     = "Air/soil temp, humidity; tissue nutrients; soil physicochemistry; plant biomass, growth rates, C stocks & sequestration",
  "Hanpattanakit 2022" = "% soil C by depth, % plant C by part, biomass & C stocks",
  "Roy 2025"           = "Soil C & N, bulk density, biomass; C stocks & sequestration",
  "Ospina Parra 2025"  = "Soil carbon, respiration, texture, porosity, hydraulic conductivity, microbial biomass C compared to matched control lawn",
  "Sharma 2026"        = "Annual C sequestration, ecosystem C storage & net-zero area Miyawaki system and mixed plantations (via InVEST model)",
  "Guo 2018"           = "Canopy cover, plant height & biomass; soil moisture, %SOM, nutrients & enzyme activity in Mini Forest, \"traditional method\", and natural forest plots",
  "Akbar 2010"         = "Soil properties, including % SOM and % organic C",
  "Schirone 2011"      = "Mortality rate, stem count, mean height by species in Mini Forest and conventional forest plantations",
  "Ranjan 2016"        = "Survival rate and mean plant height by species over time in Mini forest and \"conventional method\" plot",
  "Frattaroli 2017"    = "Mean plant height and stem count per species in Mini Forests vs. natural beech woodland",
  "Song 2020"          = "Plant community composition, growth rate, biomass",
  "Miyawaki 1993"      = "Presence/absence of insect genera in Mini forests vs. shrine forest",
  "Fratini 2023"       = "Student climate awareness, stewardship, civic participation & nature connectedness",
  "McCarthy 2023"      = "Knowledge & ranking of ecosystem services across six urban green-space types",
  "Rochard 2023"       = "Perceived mini-forest benefits & challenges (participants and City of Paris staff)",
  "Buijs 2024"         = "Perceived success/failure & drivers among citizens and NGO leaders",
  "Qi 2024"            = "Practitioner thoughts & feelings (interviews and surveys)",
  "Qi 2025"            = "Awareness, attitudes & concerns of 112 landscape professionals")

length(described)                                                                # <-- look: 19, one per study


################################################################################
# STEP 4 - "What was found?", exactly as JMB edited it on the figure
################################################################################

found <- c(
  "Goveanthan 2025"    = "Photosynthetic rate, transpiration, basal diameter & height vary over time.",
  "Sugumaran 2026"     = "Per-tree carbon stock 0.06-3.83 kg across 34 species; CO2e 0.23-14.03 kg tree-1.",
  "Hanpattanakit 2022" = "Allometric estimate: 42.15 t dry matter ha-1 biomass; 18.74 t C ha-1.",
  "Roy 2025"           = "Highest C stock and sequestration rate in the oldest Mini Forest.",
  "Ospina Parra 2025"  = "Soil C, respiration rate & microbial biomass C significantly higher in Mini Forests than lawns.",
  "Sharma 2026"        = "C sequestration rate of Mini Forest is above the cross-forest-type mean; significance untested.",
  "Guo 2018"           = "Soil physicochemistry, chemistry, microbial (CFU) counts & enzyme activity varied significantly among plots.",
  "Akbar 2010"         = "Soil variables (except % moisture) varied significantly over time and among plots.",
  "Schirone 2011"      = "Mortality 15.8-61% (site A), 10.2-84.3% (site B); species heights differ significantly among plots.",
  "Ranjan 2016"        = "Survival averaged 92% (yr 1) and 87% (yr 3) vs. 72% in a conventional plot (method undescribed).",
  "Frattaroli 2017"    = "85% of trees on low-slope sites were taller than those on high-slope sites.",
  "Song 2020"          = "Density peaked ~16,000 ha-1 & evergreens ~90% by yr 6, then declined; evergreen biomass ~40-50% by yr 12.",
  "Miyawaki 1993"      = "No Miyawaki forest reached the species richness of shrine forests.",
  "Fratini 2023"       = "Student participants report high civic participation and nature connectedness.",
  "McCarthy 2023"      = "Tiny forests perceived best for provisioning/regulating services; respondents want to help design green spaces.",
  "Rochard 2023"       = "Planting days mobilized dozens of mostly non-local volunteers; fostered citizen-practitioner learning.",
  "Buijs 2024"         = "Four success factors: tangible visible activity, local connection, nationwide critical mass, external funding.",
  "Qi 2024"            = "Recommended near schools/health sites; public engagement requires educating on Mini forests; cost a key constraint (3-4x conventional urban tree planting).",
  "Qi 2025"            = "Public-sector professionals most willing to pay; academics least engaged; parks & educational sites most suitable.")

length(found)                                                                    # <-- look: 19, one per study
setdiff(assign$label, names(described))                                          # <-- look: must be character(0) - every study has text
setdiff(assign$label, names(found))                                              # <-- look: must be character(0)


################################################################################
# STEP 5 - Assemble the table, in Figure 2 row order
################################################################################

tableS1 <- data.frame(
  Study      = assign$label,                                                     # "Surname Year"
  Urban      = assign$urban,                                                     # Yes / No - the three "No" rows are not in Figure 2
  DataType   = ifelse(assign$dtype == "Quant", "Quantitative", "Qualitative"),   # matches the Figure 2 pill
  Services   = assign$services,                                                  # ecosystem services, from the Figure 2 dots
  Described  = described[assign$label],                                          # STEP 3 text, reordered to match
  Found      = found[assign$label],                                              # STEP 4 text, reordered to match
  stringsAsFactors = FALSE)
row.names(tableS1) <- NULL                                                       # drop the study names carried in by the lookup
head(tableS1, 3)                                                                 # <-- look: first three rows read correctly
table(tableS1$Urban)                                                             # <-- look: 16 Yes, 3 No
tableS1[, c("Study", "Urban", "DataType", "Services")]                           # <-- look: the whole table before it becomes a .docx (View(tableS1) for the text too)


################################################################################
# STEP 6 - Format as a Word table: Times New Roman, header bold, text wrapped
################################################################################

ft <- flextable(tableS1)                                                         # start from the data frame
ft <- set_header_labels(ft,
        Study = "Study", Urban = "Urban site", DataType = "Data type",
        Services = "Ecosystem service(s) addressed",
        Described = "Type of data described", Found = "What was found?")         # readable column headings
ft <- font(ft, part = "all", fontname = "Times New Roman")                       # Times New Roman throughout
ft <- fontsize(ft, part = "header", size = 11)                                   # header a touch larger
ft <- fontsize(ft, part = "body",   size = 10)                                   # body text
ft <- bold(ft, part = "header")                                                  # bold headings
ft <- align(ft, j = c("Urban", "DataType"), align = "center", part = "all")      # centre the two short columns
ft <- valign(ft, valign = "top", part = "body")                                  # text sits at the top of each cell
ft <- width(ft, j = "Study",     width = 1.15)                                   # column widths, inches
ft <- width(ft, j = "Urban",     width = 0.60)
ft <- width(ft, j = "DataType",  width = 0.80)
ft <- width(ft, j = "Services",  width = 1.20)
ft <- width(ft, j = "Described", width = 2.55)
ft <- width(ft, j = "Found",     width = 2.55)
ft <- padding(ft, padding = 3, part = "all")                                     # tighten the cell padding
ft <- border_remove(ft)                                                          # start from no rules
ft <- hline_top(ft, part = "header", border = fp_border(color = "black", width = 1.2))     # rule above the headings
ft <- hline_bottom(ft, part = "header", border = fp_border(color = "black", width = 1.0))  # rule below the headings
ft <- hline_bottom(ft, part = "body", border = fp_border(color = "black", width = 1.2))    # rule under the last row
ft                                                                               # <-- look: renders in the RStudio Viewer pane


################################################################################
# STEP 7 - Write the .docx (landscape, so the two text columns have room)
################################################################################

doc <- read_docx()                                                               # a blank Word document
doc <- body_add_fpar(doc, fpar(                                                  # the table caption
        ftext("Table S1. ", fp_text(font.family = "Times New Roman", font.size = 11, bold = TRUE)),
        ftext(paste("What each empirical Mini Forest study measured and what it found.",
                    "All 19 peer-reviewed, Scopus/Web of Science-indexed studies reporting empirical data on Mini Forests are listed,",
                    "in the same top-to-bottom order as Figure 2. Figure 2 shows only the 16 studies at urban sites;",
                    "the three studies marked \"No\" under Urban site (Schirone 2011, Ranjan 2016, Frattaroli 2017) are reported here only.",
                    "Ecosystem service assignments are the ones drawn as dots in Figure 2."),
              fp_text(font.family = "Times New Roman", font.size = 11))))
doc <- body_add_par(doc, "")                                                     # blank line between caption and table
doc <- body_add_flextable(doc, ft)                                               # the table
doc <- body_end_section_landscape(doc)                                           # landscape page - the table is ~8.9 in wide
print(doc, target = "TableS1_evidence_text.docx")


################################################################################
# STEP 8 - Check the condensed text against the verbatim spreadsheet cells
#          The table above shows CONDENSED wording. The verbatim 'Measurements'
#          and 'Results' cells travel in the assignments CSV, so they can be read
#          straight off `assign` - no re-matching of study names required.
################################################################################

review <- data.frame(
  Study                 = tableS1$Study,                                         # same order as Table S1
  Described             = tableS1$Described,                                     # condensed wording shown in the table
  Measurements_verbatim = assign$measurements_verbatim,                          # what the workbook actually says
  Found                 = tableS1$Found,                                         # condensed wording shown in the table
  Results_verbatim      = assign$results_verbatim,                               # what the workbook actually says
  stringsAsFactors = FALSE)

nrow(review)                                                                     # <-- look: 19, no duplicated rows
review[, c("Study", "Described", "Measurements_verbatim")]                        # <-- look: read this before trusting Table S1
write.csv(review, "TableS1_condensed_vs_verbatim.csv",
          row.names = FALSE)

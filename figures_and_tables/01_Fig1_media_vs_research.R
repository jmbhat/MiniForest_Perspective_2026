################################################################################
# 01_Fig1_media_vs_research.R
#
# FIGURE 1 - Media attention vs. academic research on Mini Forests
#   Panel A - news articles per year (lines) vs. academic publications (bars), 2015-2025
#   Panel B - nested evidence funnel across all Mini Forest papers identified
#
# Data in:
#   papers - Mini_Forest_academic_corpus.xlsx, sheet "Paper_analysis"
#   media  - Mini_Forest_merged_media_corpus.xlsx,  sheet "Merged_corpus"
#
# Figure out:
#   Figure1_mini_forest_media_vs_research_2015-2025.{pdf,png,svg}
#
# Style: Times New Roman throughout, enlarged text, Panel A legend ABOVE the panel.
# Run one STEP at a time and look at the objects flagged with "# <-- look:".
################################################################################


################################################################################
# STEP 1 - Packages
################################################################################

library(readxl)                                                                  # read the two .xlsx workbooks
library(ggplot2)                                                                 # all plotting
library(patchwork)                                                               # stack Panel A over Panel B
library(svglite)                                                                 # .svg export with live text
library(ragg)                                                                    # .png export with system fonts (Times New Roman)


################################################################################
# STEP 2 - Read the ADJUSTED paper analysis (108 records, all publication years)
################################################################################

paper_raw <- read_excel("data/Mini_Forest_academic_corpus.xlsx",
                       sheet = "Paper_analysis", .name_repair = "minimal")       # adjusted workbook - the one figure numbers come from
names(paper_raw) <- trimws(names(paper_raw))                                     # a few headers carry trailing spaces ("Peer reviewed? ")
names(paper_raw)                                                                 # <-- look: confirm the 31 column names below still match the sheet
nrow(paper_raw)                                                                  # <-- look: 108 data rows


################################################################################
# STEP 3 - Build one tidy paper-level data frame, columns addressed BY NAME
#          Every screening column is Yes/No text -> convert to TRUE/FALSE here.
################################################################################

papers <- data.frame(
  Authors   = as.character(paper_raw$`Authors`),                                                                   # first author string
  Year      = as.integer(regmatches(as.character(paper_raw$`Year`), regexpr("[0-9]{4}", as.character(paper_raw$`Year`)))),  # first 4-digit year in the cell
  indexed   = grepl("^yes", tolower(trimws(as.character(paper_raw$`Index`)))),                                     # indexed in Scopus or Web of Science
  empirical = grepl("^yes", tolower(trimws(as.character(paper_raw$`Empirical data on Mini Forest?`)))),         # reported field-measured data
  peer_rev  = grepl("^yes", tolower(trimws(as.character(paper_raw$`Peer reviewed?`)))),                            # peer reviewed
  comp_tree = grepl("^yes", tolower(trimws(as.character(paper_raw$`Comparison to other types of urban tree planting?`)))),  # compared to another urban tree planting
  rep_mini  = grepl("^yes", tolower(trimws(as.character(paper_raw$`Replicated Mini Forests?`)))),              # >1 replicated Mini Forest
  rep_comp  = grepl("^yes", tolower(trimws(as.character(paper_raw$`Replicated Comparison plots?`)))),              # >1 replicated comparison plot
  stat_tree = grepl("^yes", tolower(trimws(as.character(paper_raw$`Statistical tests of claim against other types of urban tree planting?`)))),  # stats vs. tree planting
  stat_gree = grepl("^yes", tolower(trimws(as.character(paper_raw$`Statistical tests of claim against other types of urban greening?`)))),       # stats vs. urban greening
  stringsAsFactors = FALSE)

papers <- papers[!is.na(papers$Authors) & papers$Authors != "NA", ]              # drop any blank spacer rows at the bottom of the sheet
nrow(papers)                                                                     # <-- look: 108 papers carried forward
range(papers$Year, na.rm = TRUE)                                                 # <-- look: full publication-year span used in the Panel B axis title
head(papers, 3)                                                                  # <-- look: one row per paper, screening columns now TRUE/FALSE (View(papers) for all 108)


################################################################################
# STEP 4 - Academic publications per year, 2015-2025 (the Panel A bars)
################################################################################

acad_by_year <- as.data.frame(table(factor(papers$Year, levels = 2015:2025)))    # count papers per year, keeping empty years as 0
names(acad_by_year) <- c("Year", "n_papers")                                     # rename the table() output columns
acad_by_year$Year <- as.integer(as.character(acad_by_year$Year))                 # factor level -> integer year for the x axis
acad_by_year                                                                     # <-- look: 2015=2 ... 2021=9 ... 2025=25
sum(acad_by_year$n_papers)                                                       # <-- look: 94 papers fall inside the 2015-2025 window


################################################################################
# STEP 5 - News articles per year, 2015-2025 (the Panel A lines)
#          "about"   = classification Miyawaki + Likely_Miyawaki
#          "passing" = classification Passing_Mention
################################################################################

media <- read_excel("data/Mini_Forest_merged_media_corpus.xlsx",
                    sheet = "Merged_corpus")                                     # 5,075 de-replicated MediaCloud + ProQuest records
media$year <- suppressWarnings(as.integer(media$year))                           # year arrives as text in some rows
nrow(media)                                                                      # <-- look: 5075 media records before any filtering

about_by_year <- as.data.frame(table(factor(media$year[media$classification %in% c("Miyawaki", "Likely_Miyawaki")], levels = 2015:2025)))  # articles ABOUT Mini Forests
names(about_by_year) <- c("Year", "n_about")                                     # rename the table() output columns
about_by_year$Year <- as.integer(as.character(about_by_year$Year))               # factor level -> integer year
sum(about_by_year$n_about)                                                       # <-- look: 1,160 articles about Mini Forests

passing_by_year <- as.data.frame(table(factor(media$year[media$classification == "Passing_Mention"], levels = 2015:2025)))                 # articles with a PASSING mention
names(passing_by_year) <- c("Year", "n_passing")                                 # rename the table() output columns
passing_by_year$Year <- as.integer(as.character(passing_by_year$Year))           # factor level -> integer year
sum(passing_by_year$n_passing)                                                   # <-- look: 2,575 passing-mention articles


################################################################################
# STEP 6 - Assemble the two Panel A plotting frames
################################################################################

panelA_bars <- acad_by_year                                                      # bars: one row per year, n_papers
panelA_bars                                                                      # <-- look: the numbers printed above each bar

panelA_lines <- rbind(
  data.frame(Year = about_by_year$Year,   n = about_by_year$n_about,     series = "News articles - about Mini Forests"),          # green line
  data.frame(Year = passing_by_year$Year, n = passing_by_year$n_passing, series = "News articles - passing mention of Mini Forests"))  # amber line
panelA_lines$series <- factor(panelA_lines$series,
  levels = c("News articles - passing mention of Mini Forests",                  # amber listed first so it sits on top of the legend stack
             "News articles - about Mini Forests"))                              # green listed second, matching the example figure
panelA_lines                                                                     # <-- look: 22 rows = 11 years x 2 series

y_top_A <- max(panelA_lines$n) * 1.12                                            # headroom above the tallest (2021 passing-mention) point


################################################################################
# STEP 7 - PANEL A: bars = academic publications, lines = news articles
#          Times New Roman, enlarged text, legend stacked ABOVE the panel.
################################################################################

panelA <- ggplot() +
  geom_col(data = panelA_bars, aes(Year, n_papers, fill = "Academic publications"),
           width = 0.55, colour = "black", linewidth = 0.3) +                    # charcoal bars, one per year
  geom_text(data = panelA_bars, aes(Year, n_papers + y_top_A * 0.015, label = n_papers),
            vjust = 0, size = 4.6, family = "Times", colour = "#37474F") +       # print the paper count above each bar
  geom_line(data = panelA_lines, aes(Year, n, colour = series), linewidth = 1.0) +   # the two media trend lines
  geom_point(data = panelA_lines, aes(Year, n, colour = series, shape = series),
             size = 3.0, stroke = 0.8, fill = "white") +                         # open squares (passing) / open circles (about)
  scale_fill_manual(NULL, values = c("Academic publications" = "#37474F")) +     # charcoal; label kept short, n reported in the figure legend
  scale_colour_manual(NULL, values = c("News articles - passing mention of Mini Forests" = "#E59500",   # amber
                                       "News articles - about Mini Forests"              = "#2E7D32")) + # green
  scale_shape_manual(NULL, values = c("News articles - passing mention of Mini Forests" = 22,           # open square
                                      "News articles - about Mini Forests"              = 21)) +        # open circle
  scale_x_continuous(breaks = 2015:2025) +                                       # one tick per year
  scale_y_continuous(limits = c(0, y_top_A), breaks = seq(0, 600, 200), expand = expansion(mult = c(0, 0))) +  # 0/200/400/600 as in the example
  guides(fill   = guide_legend(order = 1, direction = "vertical"),                # bars key first...
         colour = guide_legend(order = 2, direction = "vertical"),                # ...then the two media lines, one per row
         shape  = guide_legend(order = 2, direction = "vertical")) +              # shape merges into the colour key
  labs(x = NULL, y = "Number of articles per year", title = "(A)") +             # panel letter only - all wording lives in the figure legend
  theme_classic(base_size = 16, base_family = "Times") +                         # Times New Roman, enlarged base text
  theme(plot.title = element_text(size = 20, hjust = 0, margin = margin(b = 2)), # "(A)" sits at the far left, above the legend
        plot.title.position = "plot",                                            # align "(A)" to the panel edge, not the axis
        axis.title = element_text(size = 17),                                    # y-axis title
        axis.text = element_text(size = 15, colour = "black"),                   # year and count tick labels
        legend.position = "top",                                                 # <-- legend ABOVE the graph
        legend.justification = "left",                                           # left-aligned under "(A)"
        legend.box = "vertical",                                                 # the three keys stack as three rows
        legend.box.just = "left",                                                # ...all flush left
        legend.spacing.y = unit(0, "pt"),                                        # keep the three rows tight together
        legend.margin = margin(t = 0, r = 0, b = 4, l = 40),                     # indent the legend block, as in the example
        legend.text = element_text(size = 15),                                   # enlarged legend text
        legend.key.height = unit(16, "pt"),                                      # row height for the stacked keys
        panel.grid.major.y = element_line(colour = "grey85", linewidth = 0.3))   # faint horizontal guides

print(panelA)                                                                    # <-- look: legend above, Times text, bars labelled 2..25


################################################################################
# STEP 8 - PANEL B tiers: nested evidence funnel (all publication years)
#          Each tier is a strict subset of the tier above it.
################################################################################

tier1 <- papers                                                                                          # all Mini Forest-related papers identified
tier2 <- tier1[tier1$peer_rev, ]                                                                         # ...peer reviewed
tier3 <- tier2[tier2$empirical, ]                                                                        # ...with empirical data on Mini Forests
tier4 <- tier3[tier3$comp_tree, ]                                                                        # ...compared to other urban tree plantings
tier5 <- tier4[tier4$rep_mini & tier4$rep_comp, ]                                                        # ...with replicated Mini Forest AND comparison plots
tier6 <- tier5[tier5$stat_tree | tier5$stat_gree, ]                                                      # ...that statistically tested the superiority claim

funnel <- data.frame(
  label = c("All Mini Forest-related papers identified",                                                 # tier 1
            "Peer reviewed",                                                                             # tier 2
            "...with empirical data on Mini Forests",                                                    # tier 3
            "...compared to other urban tree plantings",                                                 # tier 4
            "...with replicated Mini Forest & comparison plots",                                         # tier 5
            "...that statistically tested the superiority claim"),                                       # tier 6
  n = c(nrow(tier1), nrow(tier2), nrow(tier3), nrow(tier4), nrow(tier5), nrow(tier6)),                   # papers surviving each filter
  n_indexed = c(NA, sum(tier2$indexed), sum(tier3$indexed), sum(tier4$indexed), sum(tier5$indexed), sum(tier6$indexed)),  # Scopus/WoS share; NA = tier 1 is not split
  stringsAsFactors = FALSE)

funnel$n_notindexed <- funnel$n - funnel$n_indexed                                                       # the light-blue remainder of each bar
funnel$yp <- 5:0                                                                                         # tier 1 plots at the top of the panel
funnel$pct <- funnel$n / funnel$n[1] * 100                                                               # each tier as a % of all papers identified
n_all <- funnel$n[1]                                                                                     # total papers identified; used to place the Panel B labels
funnel$right_lab <- c(sprintf("n = %d", funnel$n[1]),                                                    # tier 1 label carries no percent
                      sprintf("n = %d (%.0f%%)", funnel$n[-1], funnel$pct[-1]))                          # tiers 2-6 carry n and percent
funnel[, c("label", "n", "n_indexed", "n_notindexed")]                                                   # <-- look: 108, 67, 32, 9, 1, 0


################################################################################
# STEP 9 - PANEL B bar segments, written out one tier at a time
#          Tier 1 = single grey bar. Tiers 2-5 = dark (indexed) + light (not indexed).
#          Tier 6 is n = 0, so it gets no rectangle - only its right-hand label.
################################################################################

funnel_seg <- rbind(
  data.frame(yp = 5, xmin = 0,                  xmax = funnel$n[1],         fill = "All papers identified"),        # tier 1: one grey bar
  data.frame(yp = 4, xmin = 0,                  xmax = funnel$n_indexed[2], fill = "Indexed in Scopus / WoS"),      # tier 2 indexed
  data.frame(yp = 4, xmin = funnel$n_indexed[2], xmax = funnel$n[2],        fill = "Not indexed"),                  # tier 2 not indexed
  data.frame(yp = 3, xmin = 0,                  xmax = funnel$n_indexed[3], fill = "Indexed in Scopus / WoS"),      # tier 3 indexed
  data.frame(yp = 3, xmin = funnel$n_indexed[3], xmax = funnel$n[3],        fill = "Not indexed"),                  # tier 3 not indexed
  data.frame(yp = 2, xmin = 0,                  xmax = funnel$n_indexed[4], fill = "Indexed in Scopus / WoS"),      # tier 4 indexed
  data.frame(yp = 2, xmin = funnel$n_indexed[4], xmax = funnel$n[4],        fill = "Not indexed"),                  # tier 4 not indexed
  data.frame(yp = 1, xmin = 0,                  xmax = funnel$n_indexed[5], fill = "Indexed in Scopus / WoS"),      # tier 5 indexed
  data.frame(yp = 1, xmin = funnel$n_indexed[5], xmax = funnel$n[5],        fill = "Not indexed"))                  # tier 5 not indexed
funnel_seg <- funnel_seg[funnel_seg$xmax > funnel_seg$xmin, ]                                            # drop any zero-width segment
funnel_seg$fill <- factor(funnel_seg$fill, levels = c("All papers identified", "Indexed in Scopus / WoS", "Not indexed"))  # legend order
funnel_seg                                                                                                # <-- look: 8 rectangles after the zero-width drop


################################################################################
# STEP 10 - PANEL B: horizontal nested funnel, Times New Roman, enlarged text
################################################################################

panelB <- ggplot() +
  geom_rect(data = funnel_seg, aes(xmin = xmin, xmax = xmax, ymin = yp - 0.32, ymax = yp + 0.32, fill = fill),
            colour = "white", linewidth = 0.4) +                                 # the stacked tier bars
  geom_text(data = funnel, aes(x = pmax(n, 0.5) + n_all * 0.02, y = yp, label = right_lab),
            hjust = 0, size = 5.0, family = "Times", colour = "black") +         # n (and %) to the right of each bar
  geom_text(data = funnel, aes(x = -n_all * 0.02, y = yp, label = label),
            hjust = 1, size = 5.0, family = "Times", colour = "black") +         # tier wording to the left of the axis
  scale_fill_manual(NULL, values = c("All papers identified"    = "#9AA5B1",     # grey
                                     "Indexed in Scopus / WoS"  = "#1F4E79",     # deep blue
                                     "Not indexed"              = "#A9CCE3"),    # light blue
                    breaks = c("Indexed in Scopus / WoS", "Not indexed")) +      # legend shows only the indexing split
  scale_x_continuous(breaks = seq(0, 100, 20)) +                                 # 0,20,...,100 papers
  scale_y_continuous(expand = c(0, 0)) +                                         # no padding above/below the bar block
  coord_cartesian(xlim = c(-n_all * 0.85, n_all * 1.05),             # negative x space holds the left-hand tier labels
                  ylim = c(-0.7, 5.7), clip = "off") +                           # clip = "off" lets the n labels overflow the panel
  labs(x = sprintf("Total number of papers (%d-%d)", min(papers$Year, na.rm = TRUE), max(papers$Year, na.rm = TRUE)),  # span taken from the data
       y = NULL, title = "(B)") +                                                # panel letter only
  guides(fill = guide_legend(title = "Shaded bars - indexing:", title.position = "top")) +  # small key in the lower right
  theme_classic(base_size = 16, base_family = "Times") +                         # Times New Roman, enlarged base text
  theme(plot.title = element_text(size = 20, hjust = 0, margin = margin(b = 2)), # "(B)" at the far left
        plot.title.position = "plot",                                            # align "(B)" to the panel edge
        axis.title.x = element_text(size = 17),                                  # "Total number of papers (...)"
        axis.text.x = element_text(size = 15, colour = "black"),                 # 0-100 tick labels
        axis.line.y = element_blank(), axis.ticks.y = element_blank(), axis.text.y = element_blank(),  # tier labels replace the y axis
        panel.grid.major.x = element_line(colour = "grey85", linewidth = 0.3),   # faint vertical guides
        legend.position = c(0.99, 0.14), legend.justification = c(1, 0),         # key tucked into the empty lower-right corner
        legend.title = element_text(size = 14), legend.text = element_text(size = 13),  # enlarged but subordinate to the panel text
        plot.margin = margin(t = 5, r = 60, b = 5, l = 5))                       # right margin holds the overflowing n labels

print(panelB)                                                                    # <-- look: six tiers, labels legible, nothing clipped


################################################################################
# STEP 11 - Stack the two panels
################################################################################

figure1 <- panelA / panelB + plot_layout(heights = c(1, 1))                      # Panel A over Panel B, equal height
print(figure1)                                                                   # <-- look: the assembled Figure 1


################################################################################
# STEP 12 - Save Figure 1 (pdf for the manuscript, png to preview, svg to edit)
################################################################################

ggsave("Figure1_mini_forest_media_vs_research_2015-2025.pdf",
       figure1, width = 10, height = 9.5, device = "pdf", family = "Times")      # "pdf" + family = "Times" keeps the text live and editable

ggsave("Figure1_mini_forest_media_vs_research_2015-2025.png",
       figure1, width = 10, height = 9.5, dpi = 300, device = ragg::agg_png)     # 300 dpi preview

ggsave("Figure1_mini_forest_media_vs_research_2015-2025.svg",
       figure1, width = 10, height = 9.5, device = svglite::svglite)             # editable text for Illustrator touch-ups


################################################################################
# STEP 13 - Numbers to quote in the figure legend
################################################################################

figure1_numbers <- data.frame(
  quantity = c("Academic publications, 2015-2025 window",                        # charcoal bars
               "News articles about Mini Forests, 2015-2025",                    # green line
               "News articles passing mention, 2015-2025",                       # amber line
               "Media records screened",                                         # denominator of the media corpus
               "All Mini Forest-related papers identified",                      # Panel B tier 1
               "Peer reviewed",                                                  # Panel B tier 2
               "...with empirical data on Mini Forests",                         # Panel B tier 3
               "...compared to other urban tree plantings",                      # Panel B tier 4
               "...with replicated Mini Forest & comparison plots",              # Panel B tier 5
               "...that statistically tested the superiority claim"),            # Panel B tier 6
  value = c(sum(acad_by_year$n_papers), sum(about_by_year$n_about), sum(passing_by_year$n_passing),
            nrow(media), funnel$n[1], funnel$n[2], funnel$n[3], funnel$n[4], funnel$n[5], funnel$n[6]),
  stringsAsFactors = FALSE)
figure1_numbers                                                                  # <-- look: every n cited in the Figure 1 legend

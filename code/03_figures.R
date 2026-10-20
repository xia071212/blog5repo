# 03_figures.R
# Create the five figures used in the blog and save them to results/figures/.

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(ggrepel)
library(scales)
library(sf)
library(tigris)

figures_dir <- here("results", "figures")
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

state_avg    <- read_csv(here("results", "tables", "state_per_capita.csv"), col_types = cols(state = "c"))
us_avg       <- read_csv(here("results", "tables", "us_average.csv"), show_col_types = FALSE)
nonresident  <- read_csv(here("results", "tables", "nonresident_share_2022.csv"), col_types = cols(state = "c"))
fin_years    <- range(read_csv(here("data", "processed", "finance_panel.csv"),
                               show_col_types = FALSE)$fiscal_year)

# Map of the 50 states and DC, with Alaska and Hawaii moved below the mainland
states_map <- st_read(here("data", "raw", "state_boundaries_2022.gpkg"), quiet = TRUE) |>
  filter(STATEFP %in% state_avg$state) |>
  shift_geometry()
st_geometry(states_map) <- "geometry"   # use one name for the geometry column

# Shared look, following the earlier blog figures
ink <- "#203149"; muted <- "#536071"
col_tax <- "#264D7E"; col_other <- "#8FB3D9"; col_fed <- "#E3A1B4"
style <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 16, color = ink),
        plot.subtitle = element_text(size = 11, color = muted, margin = margin(b = 12)),
        plot.caption = element_text(size = 9, hjust = 0, color = muted),
        legend.position = "bottom", panel.grid.minor = element_blank(),
        plot.margin = margin(15, 20, 12, 12))
map_style <- style + theme(axis.text = element_blank(), panel.grid = element_blank(),
                           axis.title = element_blank())

dollars <- label_dollar(accuracy = 1)
save_figure <- function(plot, name, width, height) {
  ggsave(here("results", "figures", paste0(name, ".png")), plot, width = width, height = height, dpi = 300, bg = "white")
  ggsave(here("results", "figures", paste0(name, ".pdf")), plot, width = width, height = height, bg = "white")
}
period <- paste0("FY", fin_years[1], "-", fin_years[2], " Average")
source_census <- "Source: U.S. Census Bureau, Annual Survey of State and Local Government Finances; Census Population Estimates;\nauthor's calculations."

# Both maps share one binned color scale so they can be compared directly.
# Distinct color classes make differences between states easy to see.
map_fill <- scale_fill_fermenter(palette = "YlGnBu", direction = 1,
                                 breaks = c(6000, 8000, 10000, 12000, 15000, 20000),
                                 limits = c(4000, 32000), labels = dollars,
                                 name = "Dollars per person")

label_extremes <- function(map_data, var) {
  map_data |>
    arrange(desc(.data[[var]])) |>
    slice(c(1:3, (n() - 2):n())) |>
    mutate(label = paste0(STUSPS, " ", dollars(.data[[var]])))
}

draw_map <- function(var, title) {
  map_data <- left_join(states_map, state_avg, by = c("STATEFP" = "state"))
  labels <- label_extremes(map_data, var)
  ggplot(map_data) +
    geom_sf(aes(fill = .data[[var]]), color = "white", linewidth = 0.25) +
    geom_label_repel(data = labels, aes(geometry = geometry, label = label),
                     stat = "sf_coordinates", size = 3.2, color = ink, fill = "white",
                     label.size = 0.2, min.segment.length = 0, seed = 1) +
    map_fill +
    guides(fill = guide_coloursteps(title.position = "top", barwidth = unit(20, "lines"),
                                    barheight = unit(0.6, "lines"))) +
    labs(title = title, caption = source_census) +
    map_style
}

# Figure 1a: state and local taxes per person -------------------------------
fig1a <- draw_map("taxes_pc", paste0("State and Local Taxes per Person, ", period))
save_figure(fig1a, "fig1a_taxes_map", 9, 6.5)

# Figures 1b and 2b: the same states, order and axis ------------------------
state_order <- state_avg$state_name[order(state_avg$taxes_pc)]
bars <- state_avg |>
  select(state_name, Taxes = taxes_pc, `Fees, charges and other own revenue` = other_own_pc,
         `Federal transfers` = federal_pc) |>
  pivot_longer(-state_name, names_to = "source", values_to = "per_person") |>
  mutate(state_name = factor(state_name, levels = state_order),
         source = factor(source, levels = c("Federal transfers", "Fees, charges and other own revenue", "Taxes")))
bar_colors <- c(Taxes = col_tax, `Fees, charges and other own revenue` = col_other, `Federal transfers` = col_fed)
x_axis <- scale_x_continuous(labels = dollars, limits = c(0, max(state_avg$general_revenue_pc) * 1.04),
                             expand = expansion(mult = c(0, 0.01)), position = "top")

draw_bars <- function(data, avg, avg_label, title) {
  ggplot(data, aes(per_person, state_name, fill = source)) +
    geom_col(width = 0.75) +
    geom_vline(xintercept = avg, linetype = "22", color = ink, linewidth = 0.5) +
    annotate("text", x = avg, y = 0, label = avg_label, hjust = -0.05, size = 3.2, color = ink) +
    x_axis + scale_y_discrete(expand = expansion(add = c(1.6, 0.6))) +
    scale_fill_manual(values = bar_colors, breaks = c("Taxes", "Fees, charges and other own revenue", "Federal transfers"), name = NULL) +
    labs(title = title, x = "Dollars per person", y = NULL, caption = source_census) +
    style + theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(size = 8.5))
}

fig1b <- draw_bars(filter(bars, source == "Taxes"), us_avg$taxes_pc,
                   paste0("U.S. average ", dollars(us_avg$taxes_pc)),
                   paste0("State and Local Taxes per Person\nby State, ", period)) +
  theme(plot.title.position = "plot")
save_figure(fig1b, "fig1b_taxes_bars", 8, 10)

# Figure 2a: general revenue per person (same color scale as Figure 1a) -----
fig2a <- draw_map("general_revenue_pc", paste0("State and Local General Revenue per Person, ", period))
save_figure(fig2a, "fig2a_revenue_map", 9, 6.5)

# Figure 2b: taxes plus other own revenue plus federal transfers ------------
fig2b <- draw_bars(bars, us_avg$general_revenue_pc,
                   paste0("U.S. average ", dollars(us_avg$general_revenue_pc)),
                   paste0("General Revenue per Person by Source, ", period))
save_figure(fig2b, "fig2b_revenue_bars", 8, 10)

# Figure 3: share of 2022 tax collections paid by nonresidents --------------
# Two colors split near the median state (25%): blue below, red above.
map3 <- left_join(states_map, nonresident, by = c("STATEFP" = "state"))
labels3 <- map3 |> arrange(desc(nonresident_share)) |> slice(c(1:5, (n() - 1):n())) |>
  mutate(label = paste0(STUSPS, " ", percent(nonresident_share, accuracy = 1)))
fig3 <- ggplot(map3) +
  geom_sf(aes(fill = nonresident_share), color = "white", linewidth = 0.25) +
  geom_label_repel(data = labels3, aes(geometry = geometry, label = label), stat = "sf_coordinates",
                   size = 3.2, color = ink, fill = "white", label.size = 0.2,
                   min.segment.length = 0, seed = 1) +
  scale_fill_fermenter(palette = "RdBu", direction = -1,
                       breaks = c(0.15, 0.20, 0.25, 0.35, 0.50), limits = c(-0.05, 0.80),
                       labels = label_percent(accuracy = 1), name = "Share paid by nonresidents") +
  guides(fill = guide_coloursteps(title.position = "top", barwidth = unit(20, "lines"), barheight = unit(0.6, "lines"))) +
  labs(title = "Share of State and Local Tax Revenue Paid by Nonresidents, 2022",
       caption = paste0("Source: Tax Foundation, State-Local Tax Burdens, Calendar Year 2022 (modeled estimates); U.S. Census Bureau,\n",
                        "Annual Survey of State and Local Government Finances, FY2022; author's calculations.")) +
  map_style
save_figure(fig3, "fig3_nonresident_map", 9, 6.5)

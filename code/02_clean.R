# 02_clean.R
# Build per-capita tax and revenue measures for the 50 states and DC,
# calculate how large the gaps between states are, and estimate the share
# of each state's tax collections paid by nonresidents.

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(rvest)

processed_dir <- here("data", "processed")
tables_dir    <- here("results", "tables")
dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

# 1. Read the Census finance files and keep state-and-local totals -----------
finance_files <- list.files(here("data", "raw"), pattern = "^census_finance_\\d{4}\\.csv$",
                            full.names = TRUE)
if (length(finance_files) == 0) stop("No Census finance files found. Run 01_download.R first.")

finance_raw <- bind_rows(lapply(finance_files, read_csv, col_types = cols(.default = "c")))

# Census item codes for the three amounts we need (state plus local governments)
items <- c(LF0002 = "general_revenue",   # Revenue - Total General Revenue
           LF0008 = "taxes",             # General Revenue - From Own Sources - Total Taxes
           LF0004 = "federal")           # General Revenue - Intergovernmental - From Federal Government

finance_items <- finance_raw |>
  filter(GOVTYPE_LABEL == "State and Local", AGG_DESC %in% names(items)) |>
  transmute(state, fiscal_year = as.integer(fiscal_year),
            measure = unname(items[AGG_DESC]),
            amount = parse_number(AMOUNT)) |>
  distinct()

if (n_distinct(finance_items$measure) != 3) {
  stop("Some Census items were not found. Item codes in the files: ",
       paste(head(unique(finance_raw$AGG_DESC), 20), collapse = ", "))
}

# Each state and year must have exactly one value for each item
dupes <- count(finance_items, state, fiscal_year, measure) |> filter(n > 1)
if (nrow(dupes) > 0) stop("More than one value per state, year and item; check labels.")

# Use the three most recent fiscal years available
fin_years <- sort(unique(finance_items$fiscal_year), decreasing = TRUE)[1:3]
fin_years <- sort(fin_years)
message("Fiscal years used: ", paste(fin_years, collapse = ", "))

finance_wide <- finance_items |>
  filter(fiscal_year %in% fin_years) |>
  pivot_wider(names_from = measure, values_from = amount) |>
  # Fees, charges, interest, royalties and other own-source non-tax revenue
  mutate(other_own = general_revenue - taxes - federal)

# 2. Population and per-capita amounts --------------------------------------
population <- read_csv(here("data", "raw", "census_population.csv"),
                       col_types = cols(GEOID = "c")) |>
  filter(variable == "POPESTIMATE", year %in% fin_years) |>
  transmute(state = GEOID, state_name = NAME, fiscal_year = as.integer(year),
            population = value)

# Census finance amounts are reported in thousands of dollars
panel <- finance_wide |>
  inner_join(population, by = c("state", "fiscal_year")) |>
  filter(state != "72") |>
  mutate(across(c(general_revenue, taxes, federal, other_own),
                ~ .x * 1000 / population, .names = "{.col}_pc"))

if (n_distinct(panel$state) != 51) {
  stop("Expected 50 states and DC, found ", n_distinct(panel$state), " jurisdictions.")
}
# Sanity check on units: typical state-local taxes are several thousand dollars per person
if (!between(median(panel$taxes_pc), 2000, 20000)) {
  stop("Median taxes per person is ", round(median(panel$taxes_pc)),
       " dollars; check the units of the Census amounts.")
}

write.csv(panel, here("data", "processed", "finance_panel.csv"), row.names = FALSE)

# 3. Three-year averages for each state -------------------------------------
state_avg <- panel |>
  group_by(state, state_name) |>
  summarise(across(c(taxes_pc, other_own_pc, federal_pc, general_revenue_pc), mean),
            .groups = "drop") |>
  arrange(desc(taxes_pc)) |>
  mutate(rank_taxes = row_number(),
         rank_general_revenue = rank(-general_revenue_pc, ties.method = "first"))

write.csv(state_avg, here("results", "tables", "state_per_capita.csv"), row.names = FALSE)

# U.S. average: total dollars divided by total population, averaged over years
us_avg <- panel |>
  group_by(fiscal_year) |>
  summarise(taxes_pc = sum(taxes * 1000) / sum(population),
            other_own_pc = sum(other_own * 1000) / sum(population),
            federal_pc = sum(federal * 1000) / sum(population),
            general_revenue_pc = sum(general_revenue * 1000) / sum(population)) |>
  summarise(across(c(taxes_pc, other_own_pc, federal_pc, general_revenue_pc), mean))

write.csv(us_avg, here("results", "tables", "us_average.csv"), row.names = FALSE)

# 4. How large are the gaps between states? ---------------------------------
gap <- function(x, name, measure) {
  q <- quantile(x, c(0.1, 0.9), names = FALSE)
  data.frame(measure = measure,
             highest_state = name[which.max(x)], highest = max(x),
             lowest_state  = name[which.min(x)], lowest  = min(x),
             max_to_min = max(x) / min(x),
             p90 = q[2], p10 = q[1], p90_to_p10 = q[2] / q[1],
             coef_variation = sd(x) / mean(x))
}

gap_measures <- rbind(
  gap(state_avg$taxes_pc, state_avg$state_name, "Taxes per person"),
  gap(state_avg$general_revenue_pc, state_avg$state_name, "General revenue per person"))

write.csv(gap_measures, here("results", "tables", "gap_measures.csv"), row.names = FALSE)

# Ten highest-tax versus ten lowest-tax states: average of each revenue source
tax_groups <- bind_rows(
  slice_max(state_avg, taxes_pc, n = 10) |> mutate(group = "Ten highest-tax states"),
  slice_min(state_avg, taxes_pc, n = 10) |> mutate(group = "Ten lowest-tax states")) |>
  group_by(group) |>
  summarise(states = paste(state_name, collapse = ", "),
            across(c(taxes_pc, other_own_pc, federal_pc, general_revenue_pc), mean))

write.csv(tax_groups, here("results", "tables", "tax_group_comparison.csv"), row.names = FALSE)

# 5. Share of tax collections paid by nonresidents (2022) -------------------
# Tax Foundation Table 2 gives, per resident, the taxes paid to the home state.
# Comparing that with what the state actually collects per resident shows how
# much of the state's tax revenue came from people living elsewhere.
tf_tables <- html_table(read_html(here("data", "raw", "taxfoundation_burdens_2022.html")),
                        fill = TRUE)
has_split <- vapply(tf_tables, function(t) any(grepl("Own State", names(t), ignore.case = TRUE)),
                    logical(1))
if (!any(has_split)) stop("Tax Foundation Table 2 was not found in the saved page.")
tf <- tf_tables[[which(has_split)[1]]]

own_col <- grep("Own State", names(tf), ignore.case = TRUE, value = TRUE)[1]
tf <- tf |>
  transmute(state_name = trimws(.data[[names(tf)[1]]]),
            tf_own_state_pc = parse_number(.data[[own_col]])) |>
  mutate(state_name = recode(state_name, "D.C." = "District of Columbia",
                             "DC" = "District of Columbia",
                             "Washington, D.C." = "District of Columbia")) |>
  filter(!is.na(tf_own_state_pc))

nonresident <- panel |>
  filter(fiscal_year == 2022) |>
  select(state, state_name, census_taxes_pc = taxes_pc) |>
  inner_join(tf, by = "state_name") |>
  mutate(nonresident_share = 1 - tf_own_state_pc / census_taxes_pc) |>
  arrange(desc(nonresident_share))

if (nrow(nonresident) != 51) {
  stop("Matched ", nrow(nonresident), " of 51 jurisdictions with Tax Foundation data. ",
       "Unmatched names: ", paste(setdiff(tf$state_name, nonresident$state_name), collapse = ", "))
}

write.csv(nonresident, here("results", "tables", "nonresident_share_2022.csv"), row.names = FALSE)
write.csv(data.frame(median_nonresident_share = median(nonresident$nonresident_share)),
          here("results", "tables", "nonresident_median_2022.csv"), row.names = FALSE)

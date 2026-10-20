# 01_download.R
# Download the raw data for Blog 5 and save a snapshot in data/raw/.
# A file that already exists is not downloaded again, so readers can
# reproduce the analysis from the saved snapshot without an API key.

library(here)
library(httr)
library(jsonlite)
library(tidycensus)
library(tigris)
library(sf)

# Set to TRUE to download every file again (results may then differ,
# because the Census Bureau revises historical data)
refresh <- FALSE

# Create the folder for raw files if it does not already exist
raw_dir <- here("data", "raw")
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

needs_download <- function(path) refresh || !file.exists(path)

census_key <- Sys.getenv("CENSUS_API_KEY")
check_key <- function() {
  if (census_key == "") {
    stop("CENSUS_API_KEY not found. Add the line CENSUS_API_KEY=yourkey to ",
         "blog5repo/.Renviron (no spaces), then restart R.")
  }
}

sources <- data.frame(file = character(), url = character())

# 1. Census Annual Survey of State and Local Government Finances -------------
# One request per fiscal year. Each request returns every revenue and spending
# item for every state and level of government (amounts in $1,000);
# 02_clean.R keeps the state-and-local totals we need.
finance_url <- "https://api.census.gov/data/timeseries/govslocalfin"
finance_vars <- "GOVTYPE,GOVTYPE_LABEL,AGG_DESC,AGG_DESC_LABEL,AMOUNT"

for (yr in 2021:2024) {
  out_file <- here("data", "raw", paste0("census_finance_", yr, ".csv"))
  request <- paste0(finance_url, "?get=", finance_vars,
                    "&for=state:*&time=", yr)
  sources <- rbind(sources, data.frame(file = basename(out_file), url = request))
  if (!needs_download(out_file)) next

  check_key()
  resp <- GET(paste0(request, "&key=", census_key), timeout(300))
  if (status_code(resp) %in% c(204, 404)) {
    message("Census finance data are not available for fiscal year ", yr, "; skipped.")
    next
  }
  stop_for_status(resp)
  rows <- fromJSON(content(resp, as = "text", encoding = "UTF-8"))
  finance <- as.data.frame(rows[-1, , drop = FALSE], stringsAsFactors = FALSE)
  names(finance) <- rows[1, ]
  finance$fiscal_year <- yr
  write.csv(finance, out_file, row.names = FALSE)
  message("Saved ", basename(out_file), " (", nrow(finance), " rows)")
}

# 2. Census population estimates (July 1 of each year) -----------------------
pop_file <- here("data", "raw", "census_population.csv")
sources <- rbind(sources, data.frame(
  file = basename(pop_file),
  url = "Census Population Estimates Program, vintage 2024, via tidycensus::get_estimates()"))
if (needs_download(pop_file)) {
  check_key()
  population <- get_estimates(geography = "state", variables = "POPESTIMATE",
                              vintage = 2024, time_series = TRUE,
                              key = census_key)
  write.csv(population, pop_file, row.names = FALSE)
}

# 3. State boundaries (Census cartographic boundary file, 1:20 million) ------
map_file <- here("data", "raw", "state_boundaries_2022.gpkg")
sources <- rbind(sources, data.frame(
  file = basename(map_file),
  url = "Census cartographic boundary file, states, 2022, 1:20m, via tigris::states()"))
if (needs_download(map_file)) {
  boundaries <- states(cb = TRUE, resolution = "20m", year = 2022)
  st_write(boundaries, map_file, delete_dsn = TRUE, quiet = TRUE)
}

# 4. Tax Foundation, State-Local Tax Burdens, Calendar Year 2022 -------------
# The page contains Table 2, which splits each state's resident tax burden
# into taxes paid to the home state and taxes paid to other states.
tf_url <- "https://taxfoundation.org/data/all/state/tax-burden-by-state-2022/"
tf_file <- here("data", "raw", "taxfoundation_burdens_2022.html")
sources <- rbind(sources, data.frame(file = basename(tf_file), url = tf_url))
if (needs_download(tf_file)) {
  resp <- GET(tf_url, user_agent("Mozilla/5.0 (course research project)"), timeout(120))
  stop_for_status(resp)
  writeBin(content(resp, as = "raw"), tf_file)
}

# Record what was downloaded, when, and a checksum for each file -------------
sources <- sources[file.exists(here("data", "raw", sources$file)), ]
paths <- here("data", "raw", sources$file)
sources$downloaded_utc <- format(file.info(paths)$mtime, tz = "UTC", usetz = TRUE)
sources$md5 <- unname(tools::md5sum(paths))
write.csv(sources, here("data", "raw", "manifest.csv"), row.names = FALSE)

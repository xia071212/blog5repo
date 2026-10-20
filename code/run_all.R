# run_all.R
# Run the whole analysis in order: download, clean, figures.
# Open blog5repo.Rproj in RStudio, then open this file and click Source.

required <- c("here", "httr", "jsonlite", "tidycensus", "tigris", "sf", "dplyr", "tidyr",
              "readr", "rvest", "ggplot2", "ggrepel", "scales", "lwgeom")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) stop("Install required packages first: ", paste(missing, collapse = ", "))

library(here)
source(here("code", "01_download.R"))
source(here("code", "02_clean.R"))
source(here("code", "03_figures.R"))

# Record the R and package versions used
writeLines(capture.output(sessionInfo()), here("session-info.txt"))

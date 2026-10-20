# Low Taxes, Deep Pockets? Who Funds Your State?

This repository accompanies the blog post **“Low Taxes, Deep Pockets? Who Funds Your State?”** The post asks whether U.S. states that collect more tax per person really have richer governments, or whether other money changes the picture. It answers three questions in turn:

1. How far apart are state and local taxes per person across the 50 states and DC?
2. Does the gap narrow once fees, natural-resource royalties and federal grants are added, giving total general revenue?
3. How much of each state's tax revenue is paid by people who live elsewhere?

The main findings are that taxes per person differ about threefold between the highest and lowest jurisdictions; that counting all general revenue barely narrows this gap, because federal grants flow more to high-tax states; and that energy states such as Alaska, Wyoming and New Mexico are the exception, with large non-tax revenue and a large share of taxes paid by nonresidents.

The repository contains the raw data snapshot, the R code that processes it, and every table and figure used in the post. With it, readers can recreate the five figures and all numbers quoted in the post, and check how each measure was calculated.

## Data

### Raw data (`data/raw/`)

| File | Source | Contents |
|---|---|---|
| [`census_finance_2021.csv`](data/raw/census_finance_2021.csv), [`_2022`](data/raw/census_finance_2022.csv), [`_2023`](data/raw/census_finance_2023.csv), [`_2024`](data/raw/census_finance_2024.csv) | [U.S. Census Bureau, Annual Survey of State and Local Government Finances](https://www.census.gov/programs-surveys/gov-finances.html), API dataset [`timeseries/govslocalfin`](https://api.census.gov/data/timeseries/govslocalfin/variables.html) | One file per fiscal year. Every revenue and spending item for every state, separately for state governments, local governments and both combined. Columns give the government level (`GOVTYPE_LABEL`), the item code and name (`AGG_DESC`, `AGG_DESC_LABEL`) and the amount in thousands of dollars (`AMOUNT`). Most states' fiscal year runs from July to June. The 2021 file is downloaded but not used, because the analysis keeps the three most recent years. |
| [`census_population.csv`](data/raw/census_population.csv) | Census Population Estimates Program, vintage 2024 | Resident population on July 1 of each year, 2020–2024, for the 50 states, DC and Puerto Rico. |
| [`state_boundaries_2022.gpkg`](data/raw/state_boundaries_2022.gpkg) | Census cartographic boundary file, 2022, 1:20 million | State outlines used to draw the maps, identified by state FIPS code. |
| [`taxfoundation_burdens_2022.html`](data/raw/taxfoundation_burdens_2022.html) | [Tax Foundation, State-Local Tax Burdens, Calendar Year 2022](https://taxfoundation.org/data/all/state/tax-burden-by-state-2022/) | Saved copy of the web page. Its Table 2 gives, for each state, the taxes its residents pay per person, split into taxes paid to their own state and taxes paid to other states. These are modeled estimates. |
| [`manifest.csv`](data/raw/manifest.csv) | Created by the download script | Source URL, download time and checksum of each raw file. The snapshot was downloaded on October 19, 2026; the Census Bureau revises historical data, so later downloads may differ. |

### Processed data (`data/processed/`)

| File | Contents |
|---|---|
| [`finance_panel.csv`](data/processed/finance_panel.csv) | One row per state and fiscal year (51 jurisdictions × FY2022–2024). Holds general revenue, taxes, federal transfers and other own revenue in thousands of dollars, the population, and each amount per person. All later results are built from this file. |

### How the data are processed

All amounts are for state and local governments combined. States divide responsibilities differently, for example by leaving schools to local districts, so combining the two levels compares states on equal terms. All values are nominal dollars, not adjusted for differences in living costs. The steps below follow the order of the post.

**1. Taxes per person (Figures 1a and 1b).** From the Census files, the analysis keeps total taxes (item `LF0008`) for the combined state-and-local level. For state $s$ in fiscal year $t$, taxes are divided by the July 1 population of the same year, and the three years are averaged:

$$\text{Taxes per person}_s = \frac{1}{3}\sum_{t=2022}^{2024} \frac{\text{Taxes}_{s,t}}{\text{Population}_{s,t}}$$

The size of the gap across the 51 jurisdictions is summarized in three ways, each computed from the per-person values above: the highest value divided by the lowest; the 90th percentile divided by the 10th, which is not driven by a single extreme state; and the coefficient of variation, the standard deviation divided by the mean. The U.S. average is total taxes in all jurisdictions divided by total population, averaged over the three years.

**2. General revenue per person and its sources (Figures 2a and 2b).** General revenue (item `LF0002`) is all revenue a government can spend on public services. It excludes utility, liquor-store and insurance-trust revenue such as pension investment returns. It is split into three sources:

$$\text{General revenue} = \text{Taxes} + \text{Federal transfers} + \text{Other own revenue}$$

Federal transfers are intergovernmental revenue from the federal government (item `LF0004`). Other own revenue is the remainder: fees and charges, tuition, interest, natural-resource royalties and similar items. Each source is converted to dollars per person and averaged over FY2022–2024 in the same way as taxes. The same three gap statistics are then computed for general revenue, so they can be compared with those for taxes. To see which sources fill or widen the gap, the analysis also averages each source over the ten highest-tax and the ten lowest-tax jurisdictions.

**3. Share of tax revenue paid by nonresidents (Figure 3).** Tax Foundation's Table 2 is read from the saved page, and each state is matched to its Census taxes per person for fiscal year 2022:

$$\text{Nonresident share}_s = 1 - \frac{\text{Taxes residents paid to their own state, per person (Tax Foundation, 2022)}}{\text{Taxes the state collected, per person (Census, FY2022)}}$$

A value of 0.5 means about half of the state's tax revenue came from people living elsewhere. Because Tax Foundation uses calendar years and modeled estimates while the Census uses fiscal years, a value near zero can turn slightly negative (Connecticut, −2%); such values are reported as computed.

**4. From results to figures.** Each per-person measure is joined to the state boundaries by FIPS code, with Alaska and Hawaii moved below the mainland. Figures 1a and 2a share one set of color classes, so the two maps can be compared directly. Figures 1b and 2b list the jurisdictions in the same order, sorted by taxes per person, on the same horizontal axis, with a dashed line at the U.S. average. Figure 3 uses two colors split near the median state: blue below and red above. Each map labels its highest and lowest jurisdictions.

## Code

| Script | Role |
|---|---|
| [`code/01_download.R`](code/01_download.R) | Downloads the Census finance data, population estimates, state boundaries and the Tax Foundation page, and writes the manifest. If a raw file already exists, it is reused instead of downloaded again. |
| [`code/02_clean.R`](code/02_clean.R) | Carries out steps 1–3 above: selects the state-and-local totals, computes per-person amounts and three-year averages, the gap statistics, the high-tax versus low-tax comparison, and the nonresident shares. Saves the processed data and result tables. |
| [`code/03_figures.R`](code/03_figures.R) | Carries out step 4: draws the five figures and saves them as PNG and PDF. |
| [`code/run_all.R`](code/run_all.R) | Runs the three scripts in order and records the R and package versions in `session-info.txt`. |

## Results

Result tables are in `results/tables/` and figures in `results/figures/`. They are listed in the order they appear in the post.

| Output | Section of the post | What it shows |
|---|---|---|
| `fig1a_taxes_map` (PNG / PDF) | How far apart are state tax bills? | Map of taxes per person, showing where taxes are high and low. |
| `fig1b_taxes_bars` (PNG / PDF) | How far apart are state tax bills? | Every jurisdiction ranked by taxes per person, showing how large the gap is. |
| [`state_per_capita.csv`](results/tables/state_per_capita.csv) | Sections 1 and 2 | Taxes, other own revenue, federal transfers and general revenue per person for each jurisdiction, with ranks. Source of the state values quoted in the post. |
| [`gap_measures.csv`](results/tables/gap_measures.csv) | Sections 1 and 2 | Highest and lowest jurisdictions, highest-to-lowest ratio, 90th-to-10th percentile ratio and coefficient of variation, for taxes and for general revenue. |
| [`us_average.csv`](results/tables/us_average.csv) | Sections 1 and 2 | U.S. average per person for each revenue source; used for the dashed lines in Figures 1b and 2b. |
| `fig2a_revenue_map` (PNG / PDF) | Does counting all revenue close the gap? | Map of general revenue per person, on the same color classes as Figure 1a. |
| `fig2b_revenue_bars` (PNG / PDF) | Does counting all revenue close the gap? | The same ranking with general revenue split into taxes, other own revenue and federal transfers. |
| [`tax_group_comparison.csv`](results/tables/tax_group_comparison.csv) | Does counting all revenue close the gap? | Average of each revenue source for the ten highest-tax and ten lowest-tax jurisdictions, showing that federal transfers are larger for high-tax states. |
| `fig3_nonresident_map` (PNG / PDF) | Who actually pays the taxes? | Map of the share of 2022 tax revenue paid by nonresidents. |
| [`nonresident_share_2022.csv`](results/tables/nonresident_share_2022.csv) | Who actually pays the taxes? | For each jurisdiction, Census taxes per person, Tax Foundation taxes paid to the home state, and the nonresident share. |
| [`nonresident_median_2022.csv`](results/tables/nonresident_median_2022.csv) | Who actually pays the taxes? | The median nonresident share across jurisdictions. |

## Reproduce the analysis

1. On this GitHub page, select **Code → Download ZIP**, then unzip the repository.
2. Open **blog5repo.Rproj** in RStudio (R 4.1 or newer). Opening the project sets the working directory, so all file paths work on any computer.
3. In **Tools → Install Packages**, install here, httr, jsonlite, tidycensus, tigris, sf, lwgeom, dplyr, tidyr, readr, rvest, ggplot2, ggrepel and scales.
4. Open **code/run_all.R** and click **Source**. The analysis uses the included raw-data snapshot, so no Census API key is needed. A key is needed only to download the data again; save it in a file named `.Renviron` in the project folder.
5. Find the recreated tables in **results/tables/** and the figures in **results/figures/**, and compare them with the post using the Results table above. The tested R and package versions are recorded in [session-info.txt](session-info.txt).

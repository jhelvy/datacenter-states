# Build data/processed/state_power.csv: average power draw (GW) per state,
# derived from EIA annual retail electricity sales.
#
# Source: data/raw/eia_retail_sales.csv (see data/README.md for provenance).
# This is a committed snapshot -- no live network call or API key required,
# so the pipeline is fully reproducible offline.

library(dplyr)
library(readr)

source("R/functions.R")

state_names <- c(
  AL = "Alabama", AK = "Alaska", AZ = "Arizona", AR = "Arkansas",
  CA = "California", CO = "Colorado", CT = "Connecticut", DE = "Delaware",
  DC = "District of Columbia", FL = "Florida", GA = "Georgia", HI = "Hawaii",
  ID = "Idaho", IL = "Illinois", IN = "Indiana", IA = "Iowa", KS = "Kansas",
  KY = "Kentucky", LA = "Louisiana", ME = "Maine", MD = "Maryland",
  MA = "Massachusetts", MI = "Michigan", MN = "Minnesota", MS = "Mississippi",
  MO = "Missouri", MT = "Montana", NE = "Nebraska", NV = "Nevada",
  NH = "New Hampshire", NJ = "New Jersey", NM = "New Mexico", NY = "New York",
  NC = "North Carolina", ND = "North Dakota", OH = "Ohio", OK = "Oklahoma",
  OR = "Oregon", PA = "Pennsylvania", RI = "Rhode Island",
  SC = "South Carolina", SD = "South Dakota", TN = "Tennessee", TX = "Texas",
  UT = "Utah", VT = "Vermont", VA = "Virginia", WA = "Washington",
  WV = "West Virginia", WI = "Wisconsin", WY = "Wyoming"
)

raw <- read_csv("data/raw/eia_retail_sales.csv", show_col_types = FALSE)

latest_year <- max(raw$year)

state_power <- raw |>
  filter(year == latest_year) |>
  mutate(
    state_name = unname(state_names[state]),
    avg_gw = mwh_to_avg_gw(total_sales_mwh)
  ) |>
  arrange(desc(avg_gw)) |>
  mutate(rank = row_number()) |>
  select(state, state_name, year, annual_mwh = total_sales_mwh, avg_gw, rank)

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
write_csv(state_power, "data/processed/state_power.csv")

cat("Wrote data/processed/state_power.csv (", nrow(state_power), "states,",
    "year", latest_year, ")\n")
cat("Top 3 by avg GW:\n")
print(head(state_power[, c("state", "avg_gw")], 3))

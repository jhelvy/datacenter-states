# Build data/processed/datacenters.json: validated data center records with
# coordinates projected into the same coordinate system as
# data/processed/us_states.geojson (via tigris::shift_geometry(), which
# shifts/rescales any Alaska or Hawaii points into their inset positions and
# otherwise applies the same Albers projection as the state polygons).

library(sf)
library(tigris)
library(dplyr)
library(jsonlite)

source("R/functions.R")

options(tigris_use_cache = TRUE)

raw <- read.csv("data/raw/datacenters.csv", stringsAsFactors = FALSE)
validate_datacenters(raw)

points_sf <- st_as_sf(raw, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
points_shifted <- shift_geometry(points_sf)
coords <- st_coordinates(points_shifted)

out <- raw |>
  mutate(
    x = coords[, "X"],
    y = coords[, "Y"],
    capacity_gw = mw_to_gw(capacity_mw)
  ) |>
  select(
    name, developer, state, capacity_mw, capacity_gw, power_source, status,
    notes, source_url, x, y
  )

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
write_json(out, "data/processed/datacenters.json", pretty = TRUE, digits = 2, auto_unbox = TRUE)

cat("Wrote data/processed/datacenters.json (", nrow(out), "data centers )\n")
cat("Total capacity:", round(sum(out$capacity_gw), 1), "GW\n")

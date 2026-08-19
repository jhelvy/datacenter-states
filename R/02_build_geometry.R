# Build data/processed/us_states.geojson: U.S. state boundaries, simplified
# for the web, with Alaska and Hawaii shifted/rescaled into insets below the
# continental U.S. and everything projected into a single planar coordinate
# system (ESRI:102003, USA Contiguous Albers Equal Area Conic).
#
# The exported GeoJSON intentionally stores these *projected* coordinates
# (not WGS84 lon/lat) so the front-end can draw them directly with D3's
# geoIdentity() -- no projection math happens in the browser. Data center
# points in R/03_prepare_datacenters.R are run through the identical
# transform so the two layers line up.

library(sf)
library(tigris)
library(rmapshaper)
library(dplyr)

options(tigris_use_cache = TRUE)

# 50 states + DC only (drop Puerto Rico and other insular areas -- our
# power dataset doesn't cover them).
us_state_abbrevs <- c(state.abb, "DC")

states_raw <- states(cb = TRUE, resolution = "20m", year = 2023)

states_filtered <- states_raw |>
  filter(STUSPS %in% us_state_abbrevs) |>
  select(GEOID, STATEFP, state = STUSPS, state_name = NAME)

states_shifted <- shift_geometry(states_filtered, geoid_column = "GEOID")

states_simplified <- ms_simplify(states_shifted, keep = 0.08, keep_shapes = TRUE)

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
out_path <- "data/processed/us_states.geojson"
if (file.exists(out_path)) file.remove(out_path)
st_write(states_simplified, out_path, driver = "GeoJSON", quiet = TRUE)

cat("Wrote", out_path, "(", nrow(states_simplified), "states )\n")
cat("File size:", round(file.size(out_path) / 1024, 1), "KB\n")

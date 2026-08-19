# Run the full data pipeline in order, producing everything in
# data/processed/ from the raw sources in data/raw/.

source("R/01_fetch_state_power.R")
source("R/02_build_geometry.R")
source("R/03_prepare_datacenters.R")

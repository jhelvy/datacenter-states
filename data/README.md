# Data Sources

This document records the provenance of every dataset used in this project:
where it came from, when it was retrieved, its license/terms, and the units
used. Raw data lives in `data/raw/`; derived data produced by the R scripts
in `R/` lives in `data/processed/`.

## State annual electricity consumption

- **Source**: U.S. Energy Information Administration (EIA) — Form EIA-861,
  "Annual sales to ultimate customers by state and sector" (Total Electric
  Industry), 2010–2024.
- **URL**: https://www.eia.gov/electricity/data/state/ →
  `xls/861/HS861 2010-.xlsx` (released 2025-10-07)
- **File**: `data/raw/eia_retail_sales.csv` (year, state, total_sales_mwh;
  all sectors combined, one row per state per year, 2010–2024)
- **Retrieved**: 2026-08-19
- **License**: U.S. government work — public domain.
- **Units**: megawatt-hours (MWh) per year, all sectors combined.
- **Derivation**: `data/processed/state_power.csv` uses the latest year
  (2024) and converts annual MWh to average power via
  `annual_mwh / 8760 hours / 1000` to get gigawatts (GW). See
  `R/functions.R::mwh_to_avg_gw()` and `R/01_fetch_state_power.R`.
  Sanity check: Ohio's 2024 total sales (153.7 TWh) imply ~17.6 GW average
  load, consistent with public reporting that the proposed 9.2 GW Southern
  Ohio gas plant would represent "more than half of Ohio's typical
  electrical load."

## Data centers (curated)

- **Source**: hand-curated from public reporting, utility/permit filings,
  and company announcements. No single free, comprehensive, machine-readable
  dataset of U.S. data center power capacity currently exists. (Cleanview's
  behind-the-meter dataset of 59 projects is the most complete but is
  paywalled at $4,900 — https://cleanview.co/reports/behind-the-meter-data-centers
  — cited here as a reference only, not used as a source.)
- **File**: `data/raw/datacenters.csv` (11 projects)
- **Fields**: `name, developer, state, lat, lon, capacity_mw, power_source,
  status, notes, source_url`. `power_source` is one of `grid`,
  `behind_the_meter_gas`, `mixed`, `other` (e.g. nuclear SMR); `status` is
  one of `announced`, `under_construction`, `operating`. Every row carries
  its own `source_url` linking to the reporting/company page the figures
  were drawn from.
- **Compiled**: 2026-08-19, from public reporting, company announcements,
  and utility filings (see individual `source_url` values). Where a single
  authoritative number wasn't available, the most commonly cited/most
  conservative confirmed figure was used (noted per-row in `notes`).
- **Validated by**: `R/functions.R::validate_datacenters()`, run in
  `R/03_prepare_datacenters.R`; schema enforced by
  `tests/testthat/test-functions.R`.
- **Caveat**: announced capacity is not the same as built/operating
  capacity; figures are the developers'/reporters' best public estimates
  and will change over time. This is a curated sample of marquee projects,
  not a census of U.S. data centers.

## State boundaries (map geometry)

- **Source**: U.S. Census Bureau TIGER/Line shapefiles, via the R
  `tigris` package.
- **License**: U.S. government work — public domain.
- **Derivation**: `tigris::states(cb = TRUE, resolution = "20m")` boundaries
  (50 states + DC; territories dropped) repositioned/rescaled with
  `tigris::shift_geometry()` (position = "below") so Alaska and Hawaii
  render as insets below the continental U.S., then simplified with
  `rmapshaper::ms_simplify()` for file size. See `R/02_build_geometry.R`.
- **Output**: `data/processed/us_states.geojson`. Coordinates are
  **pre-projected** (ESRI:102003, USA Contiguous Albers Equal Area Conic),
  not WGS84 lon/lat -- the front-end draws them as-is with D3's
  `geoIdentity()` rather than re-projecting in the browser. Data center
  points (`R/03_prepare_datacenters.R`) are run through the identical
  transform so the two layers align.

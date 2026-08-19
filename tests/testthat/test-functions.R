source(file.path("..", "..", "R", "functions.R"))

# mwh_to_avg_gw ---------------------------------------------------------

test_that("mwh_to_avg_gw converts correctly", {
  # 8,760,000 MWh/year = 1000 MW average = 1 GW average
  expect_equal(mwh_to_avg_gw(8760000), 1)
  expect_equal(mwh_to_avg_gw(0), 0)
})

test_that("mwh_to_avg_gw validates inputs", {
  expect_error(mwh_to_avg_gw("not numeric"), "numeric")
  expect_error(mwh_to_avg_gw(-1), "non-negative")
})

# mw_to_gw ----------------------------------------------------------------

test_that("mw_to_gw converts correctly", {
  expect_equal(mw_to_gw(9200), 9.2)
  expect_equal(mw_to_gw(0), 0)
})

test_that("mw_to_gw validates inputs", {
  expect_error(mw_to_gw("nope"), "numeric")
  expect_error(mw_to_gw(-5), "non-negative")
})

# validate_datacenters ------------------------------------------------------

valid_row <- function(...) {
  defaults <- list(
    name = "Test DC", developer = "Acme", state = "OH", lat = 39.0,
    lon = -83.0, capacity_mw = 1000, power_source = "grid",
    status = "announced", source_url = "https://example.com"
  )
  modifyList(defaults, list(...))
}

test_that("validate_datacenters passes on a well-formed row", {
  df <- as.data.frame(valid_row(), stringsAsFactors = FALSE)
  expect_invisible(validate_datacenters(df))
})

test_that("validate_datacenters catches missing columns", {
  df <- as.data.frame(valid_row(), stringsAsFactors = FALSE)
  df$source_url <- NULL
  expect_error(validate_datacenters(df), "missing required column")
})

test_that("validate_datacenters catches empty name", {
  df <- as.data.frame(valid_row(name = ""), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "non-empty name")
})

test_that("validate_datacenters catches invalid state", {
  df <- as.data.frame(valid_row(state = "ZZ"), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "invalid state")
})

test_that("validate_datacenters catches non-positive capacity", {
  df <- as.data.frame(valid_row(capacity_mw = 0), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "capacity_mw")
})

test_that("validate_datacenters catches out-of-bounds lat/lon", {
  df_lat <- as.data.frame(valid_row(lat = 100), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df_lat), "lat")

  df_lon <- as.data.frame(valid_row(lon = 10), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df_lon), "lon")
})

test_that("validate_datacenters catches invalid power_source", {
  df <- as.data.frame(valid_row(power_source = "nuclear"), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "invalid power_source")
})

test_that("validate_datacenters catches invalid status", {
  df <- as.data.frame(valid_row(status = "planned"), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "invalid status")
})

test_that("validate_datacenters catches missing source_url", {
  df <- as.data.frame(valid_row(source_url = ""), stringsAsFactors = FALSE)
  expect_error(validate_datacenters(df), "source_url")
})

# rank_states_by_power ------------------------------------------------------

test_that("rank_states_by_power sorts descending by avg_gw", {
  sp <- data.frame(state = c("A", "B", "C"), avg_gw = c(1, 3, 2))
  ranked <- rank_states_by_power(sp)
  expect_equal(ranked$state, c("B", "C", "A"))
})

test_that("rank_states_by_power breaks ties alphabetically", {
  sp <- data.frame(state = c("B", "A"), avg_gw = c(5, 5))
  ranked <- rank_states_by_power(sp)
  expect_equal(ranked$state, c("A", "B"))
})

test_that("rank_states_by_power validates required columns", {
  sp <- data.frame(state = "A", power = 1)
  expect_error(rank_states_by_power(sp), "avg_gw")
})

# curated datacenters.csv --------------------------------------------------

test_that("the curated data/raw/datacenters.csv passes validation", {
  path <- file.path("..", "..", "data", "raw", "datacenters.csv")
  skip_if_not(file.exists(path))
  df <- read.csv(path, stringsAsFactors = FALSE)
  expect_invisible(validate_datacenters(df))
  expect_gte(nrow(df), 10)
  expect_lte(nrow(df), 15)
})

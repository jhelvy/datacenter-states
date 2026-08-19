#' Convert annual electricity sales in megawatt-hours to average power in
#' gigawatts (MWh/year -> GW), the "continuous load" a state would draw if
#' its annual consumption were spread evenly across every hour of the year.
mwh_to_avg_gw <- function(annual_mwh) {
  if (!is.numeric(annual_mwh)) {
    stop("annual_mwh must be numeric", call. = FALSE)
  }
  if (any(annual_mwh < 0, na.rm = TRUE)) {
    stop("annual_mwh must be non-negative", call. = FALSE)
  }
  hours_per_year <- 8760
  (annual_mwh / hours_per_year) / 1000
}

#' Convert megawatts to gigawatts.
mw_to_gw <- function(mw) {
  if (!is.numeric(mw)) {
    stop("mw must be numeric", call. = FALSE)
  }
  if (any(mw < 0, na.rm = TRUE)) {
    stop("mw must be non-negative", call. = FALSE)
  }
  mw / 1000
}

#' Required columns and allowed values for the curated data center dataset.
datacenter_required_cols <- c(
  "name", "developer", "state", "lat", "lon", "capacity_mw",
  "power_source", "status", "source_url"
)

datacenter_power_sources <- c("grid", "behind_the_meter_gas", "mixed", "other")

datacenter_statuses <- c("operating", "under_construction", "announced")

#' Validate the raw data center data frame against the expected schema.
#' Stops with an informative error on the first violated rule; returns the
#' input invisibly on success.
validate_datacenters <- function(df) {
  missing_cols <- setdiff(datacenter_required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      "datacenters data is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  if (any(is.na(df$name) | df$name == "")) {
    stop("every data center must have a non-empty name", call. = FALSE)
  }

  if (any(!df$state %in% c(state.abb, "DC"))) {
    bad <- unique(df$state[!df$state %in% c(state.abb, "DC")])
    stop(
      "invalid state abbreviation(s): ", paste(bad, collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.numeric(df$capacity_mw) || any(df$capacity_mw <= 0)) {
    stop("capacity_mw must be numeric and positive for every row", call. = FALSE)
  }

  if (!is.numeric(df$lat) || any(df$lat < 24 | df$lat > 72)) {
    stop("lat must be numeric and within U.S. bounds", call. = FALSE)
  }

  if (!is.numeric(df$lon) || any(df$lon < -180 | df$lon > -65)) {
    stop("lon must be numeric and within U.S. bounds", call. = FALSE)
  }

  if (any(!df$power_source %in% datacenter_power_sources)) {
    bad <- unique(df$power_source[!df$power_source %in% datacenter_power_sources])
    stop(
      "invalid power_source value(s): ", paste(bad, collapse = ", "),
      " (allowed: ", paste(datacenter_power_sources, collapse = ", "), ")",
      call. = FALSE
    )
  }

  if (any(!df$status %in% datacenter_statuses)) {
    bad <- unique(df$status[!df$status %in% datacenter_statuses])
    stop(
      "invalid status value(s): ", paste(bad, collapse = ", "),
      " (allowed: ", paste(datacenter_statuses, collapse = ", "), ")",
      call. = FALSE
    )
  }

  if (any(is.na(df$source_url) | df$source_url == "")) {
    stop("every data center row must have a non-empty source_url", call. = FALSE)
  }

  invisible(df)
}

#' Rank states by descending average power (GW). Ties broken alphabetically
#' by state for a stable, deterministic order.
rank_states_by_power <- function(state_power) {
  if (!all(c("state", "avg_gw") %in% names(state_power))) {
    stop("state_power must have 'state' and 'avg_gw' columns", call. = FALSE)
  }
  ord <- order(-state_power$avg_gw, state_power$state)
  state_power[ord, ]
}

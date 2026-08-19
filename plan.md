# Implementation Plan: "Data Centers vs. States" — a tangible power-scale web app

## Context

Individual data centers are now planned at power scales that rival entire
states (e.g. the proposed Southern Ohio campus pairs a **9.2 GW** on-site gas
plant with a ~10 GW AI data center — "more than half of Ohio's typical
electrical load"). These GW figures are hard to grasp. This project builds a
**static, R-driven Quarto website** that makes the scale tangible: pick one or
more data centers, and the map lights up the set of U.S. states whose combined
average electricity draw equals that same power.

The core comparison is **average power**: a data center's announced capacity is
a continuous GW load, and a state's `annual electricity consumption (GWh) ÷
8,760 h` is its average GW load. Comparing GW-to-GW is fair and matches how the
9.2 GW plant is publicly framed against Ohio's ~17 GW average load.

**Decisions locked with the user:**
- Data-center dataset: start with **~10–15 marquee, fully-sourced projects** (expandable).
- State-matching: **user can toggle** between "biggest states first" and "closest total match."
- Stack: **static Quarto site**; R generates all data + map geometry; interactive front-end is **OJS + D3** (no server).

## Data Sources & Provenance

Every dataset gets an entry in `data/README.md` with source URL, retrieval
date, license, and units. The data-center CSV additionally carries a
**`source_url` on every row**.

| Data | Source | Access | Notes |
|---|---|---|---|
| State annual electricity consumption | **EIA** — Electricity: Retail Sales to Ultimate Customers, by state, all sectors, annual (GWh) | rOpenSci **`eia`** pkg (free API key) **or** committed bulk CSV snapshot | Convert GWh ÷ 8,760 → avg GW |
| Data centers (curated) | Public reporting, permit/utility filings, **Global Energy Monitor** open gas-plant tracker (CC BY) | Hand-built `data/raw/datacenters.csv` | Per-row `source_url`; fields incl. generation method |
| State geometry (AK/HI inset) | `tigris` state boundaries | R package | `shift_geometry()` repositions + projects AK/HI |

Cleanview's 59-project behind-the-meter dataset is the most complete but is
**paywalled ($4,900)** — we cite it as a reference, not a source.

**Decision on EIA access:** default to a **committed CSV snapshot** fetched by a
script (fully reproducible, no API key/secret in the repo — aligns with the
security rules). If the `eia` API path is used instead, the key lives only in
`.Renviron` (git-ignored), never committed.

## Architecture

Fully static. R does all computation and cartography at build time; OJS/D3 does
only lightweight, selection-dependent arithmetic in the browser.

```
R data pipeline ──► data/processed/*  ──► Quarto renders ──► _site/ (static)
  (EIA, tigris,        (CSV/GeoJSON        (OJS + D3 loads
   curated CSV)         /JSON assets)       the processed assets)
```

**Why OJS + D3 (not Shiny, Leaflet, or a pre-rendered image):**
- The highlighted-state set depends on the user's live selection, so the map
  **must** re-color client-side — a pre-rendered R image can't.
- User prefers **inset AK/HI over a realistic tiled map** → D3 vector map beats Leaflet tiles.
- R runs the Albers-USA projection via `shift_geometry()`, exporting
  **pre-projected** coordinates; D3 draws them with `geoIdentity().reflectY(true).fitSize(...)`,
  so the hard cartography stays in R. Data-center points are projected in R with
  the **same** transform so they align with the polygons.

## Repository Structure

```
datacenter-states/
├── _quarto.yml                 # website config, nav, theme
├── index.qmd                   # About: the problem, methodology, data sources, links
├── map.qmd                     # The interactive tool (OJS + D3)
├── R/
│   ├── 01_fetch_state_power.R  # EIA → data/processed/state_power.csv
│   ├── 02_build_geometry.R     # tigris shift_geometry → data/processed/us_states.geojson (projected)
│   ├── 03_prepare_datacenters.R# validate raw CSV, project points → data/processed/datacenters.json
│   ├── functions.R             # pure helpers (unit conversion, validation, ranking)
│   └── build_data.R            # runs 01–03 in order
├── data/
│   ├── README.md               # provenance for every dataset (sources, dates, license, units)
│   ├── raw/
│   │   ├── datacenters.csv      # hand-curated; one row/project; per-row source_url
│   │   └── eia_retail_sales.csv # committed EIA snapshot
│   └── processed/
│       ├── state_power.csv      # state, avg_gw, annual_gwh, rank
│       ├── us_states.geojson    # simplified, pre-projected (Albers USA, AK/HI inset)
│       └── datacenters.json     # name, state, x, y, mw, power_source, status, developer, source_url
├── tests/testthat/             # tests for functions.R (conversions, validation)
└── README.md
```

## Data Pipeline (R) — where all calculations live

`R/functions.R` (pure, unit-tested):
- `gwh_to_avg_gw(annual_gwh)` → `annual_gwh / 8760 / 1000` … (settle GWh vs MWh units in code)
- `mw_to_gw()`, input validators for the data-center schema (required cols, non-negative MW, valid `power_source` enum: `grid` / `behind_the_meter_gas` / `mixed` / `other`, valid state, non-empty `source_url`).
- `rank_states_by_power()` — returns states sorted by `avg_gw` desc (the order the "biggest first" mode walks).

`01_fetch_state_power.R`: read EIA snapshot → total sales by state (all sectors,
latest year) → `avg_gw` → write `state_power.csv`.

`02_build_geometry.R`: `tigris::states()` → drop territories → `shift_geometry()`
→ `rmapshaper::ms_simplify()` (keep files small) → write projected `us_states.geojson`.

`03_prepare_datacenters.R`: read + **validate** `datacenters.csv`; convert
lat/lon to `sf` points, transform to the **same projected CRS** as the states,
emit projected `x`/`y` → `datacenters.json`.

**testthat** covers conversions, the validation error paths, and ranking
(per the project's 80%+ coverage / 100% on calculations rules).

## Front-End (map.qmd — OJS + D3)

Loads `us_states.geojson`, `state_power.csv`, `datacenters.json`. Reactive flow:

1. **Select data centers** — checkbox/searchable list (name, state, MW, power source badge). Multi-select.
2. **Total target** = Σ selected MW → GW, shown prominently.
3. **Matching mode toggle** — `Biggest first` | `Closest match`:
   - *Biggest first*: walk `state_power` desc, accumulate until cumulative ≥ target; show the residual over/under-shoot.
   - *Closest match*: subset-sum DP over states (values rounded to ~0.1 GW, target ≤ ~500 GW → trivial cost) minimizing `|Σ − target|`.
4. **Render**: D3 draws states (`geoIdentity().reflectY(true).fitSize`), fills the matched set in an accent color, plots each selected data center as a labeled point ("Name — X GW") using its pre-projected `x`/`y`.
5. **Readout**: "This selection ≈ the entire electricity use of {states}" + the state list with each state's GW.

Optional (note, not blocking): a **utilization factor** slider (default 100%) to
scale the data-center load for a more conservative "actual average draw."

## Implementation Phases (build one step at a time)

- **Phase 0 — Scaffold**: `_quarto.yml`, `index.qmd`, `map.qmd` stubs, folder structure, `data/README.md` skeleton, `.gitignore` updates.
- **Phase 1 — State power data**: EIA snapshot + `01_fetch_state_power.R` + `functions.R` conversions + tests → `state_power.csv`. Verify a few states by hand (Ohio ≈ 17 GW).
- **Phase 2 — Geometry**: `02_build_geometry.R` → projected simplified GeoJSON with AK/HI inset. Verify by rendering once in R.
- **Phase 3 — Data-center dataset**: hand-curate ~10–15 projects in `datacenters.csv` (every row sourced) + `03_prepare_datacenters.R` + validation tests → `datacenters.json`. Document each source in `data/README.md`.
- **Phase 4 — Interactive map**: OJS + D3 in `map.qmd`; static base map + point plotting first, then selection → total → highlight, then the two matching modes + toggle.
- **Phase 5 — About page & polish**: methodology write-up, data-source links/citations, caveats; theme; responsive layout.
- **Phase 6 — Verify & deploy**: `quarto render`; confirm static `_site/`; (optional) GitHub Pages config.

## Verification

- `R/functions.R`: `devtools::test()` / `testthat` green; 100% on conversion + validation.
- Sanity checks: Ohio avg power ≈ 17 GW; 9.2 GW ≈ "half of Ohio" reproduced; Σ of all states ≈ national average (~450 GW).
- `datacenters.json`: every row has a resolvable `source_url` and valid `power_source`.
- Visual: AK/HI sit as insets; data-center points land in the correct states; highlighted set's Σ GW matches the readout in both modes; multi-select sums correctly.
- `quarto render` produces a self-contained static site that works from `file://` (no server).

## Risks & Notes

- **Data-center data is inherently soft** (announced ≠ built; capacity definitions vary). Mitigate with per-row `status`, `source_url`, and an explicit caveat on the About page.
- **Client-side subset logic** is the one place calculation leaves R (it depends on live selection). Kept minimal; all numeric prep/ordering is precomputed in R so JS only accumulates.
- **Rendering**: per the user's rules I will **never** run `quarto render` — the user renders all Quarto/RMd themselves. I *can* run the R data scripts to produce and verify the processed assets (CSV/GeoJSON/JSON). **No `git` commands** — the user commits.

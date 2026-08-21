# CLAUDE.md

Guidance for Claude Code working in this repository.

## What this is

A static Quarto website that makes AI data center power demand tangible by
comparing it against whole U.S. states. R generates all data and map geometry at
build time; the interactive front end is Observable JS (OJS) plus D3, so the
published site runs entirely in the browser with no server.

## Commands

```sh
# Regenerate data/processed/* from data/raw/* (run in R, only when data changes)
Rscript -e 'source("R/build_data.R")'

# Render / preview the site
quarto render
quarto preview

# Tests for the R pipeline
Rscript -e 'testthat::test_dir("tests/testthat")'
```

## Architecture

```
data/raw/*.csv  ──R/*.R──►  data/processed/*  ──Quarto+OJS──►  _site/
```

- `R/build_data.R` sources `01_fetch_state_power.R`, `02_build_geometry.R`, and
  `03_prepare_datacenters.R` in order. Shared helpers and the data-center schema
  live in `R/functions.R`.
- `data/processed/` is **committed to git**. The pages read it at runtime; CI
  never runs R. Regenerate and commit it whenever the raw data changes.
- `index.qmd` is the whole app. `about.qmd` is prose. `styles.css` carries the
  entire visual system, including the dashboard grid and every SVG fill. Its
  `--dcs-*` custom properties at the top are the design tokens; everything else
  reads from those or from Bootstrap's `--bs-*` variables.
- Fonts are Raleway (display: headings, KPI numbers) and Inter (body/UI), pulled
  from Google Fonts by the `include-in-header` block in `_quarto.yml`. Raleway is
  deliberately kept off small UI text, where it is hard to read.
- `og-card.png` (the social share image) and `favicon.svg` live at the repo root.
  `Rscript R/og_card.R` regenerates the card; it is a standalone script, not part
  of `build_data.R`, and the PNG is committed.

## Working in index.qmd

Every code cell is `{ojs}`. There are no R chunks in any `.qmd`.

- **OJS is a reactive dataflow graph, not a script.** Cell order controls only
  where output lands on the page, never evaluation order. Moving a block is a
  layout change; renaming a cell ripples to every cell that references it.
- **New data files need two edits**: load them with `FileAttachment(...)` *and*
  add them to the `resources:` list in the front matter, or Quarto will not copy
  them into `_site/`.
- **State geometry is pre-projected.** `02_build_geometry.R` writes GeoJSON in
  ESRI:102003 with AK/HI repositioned by `shift_geometry()`, which is why the map
  uses `d3.geoIdentity()` rather than a live projection. Data center `x`/`y` are
  pushed through the same transform, so never project raw lon/lat in the browser.
- **`stateTone(abbr)` is the single source of truth for how a state is colored.**
  The map, the treemap, and any future view must all go through it so they cannot
  disagree. It returns `"below" | "above" | "matched" | "unmatched"`, and the
  matching CSS classes are `.state-*` on the map and `.tm-*` in the treemap.
- Comparison modes: `smaller` is a threshold filter (states drawing less power
  than the selection); `smallest` and `closest` are subset-sum strategies that
  populate `match` / `matchedStateSet`. The subset-sum DP is skipped entirely in
  `smaller` mode.
- **`chart` and `chartUpdate` are split on purpose.** `chart` depends only on the
  geometry and is built exactly once; `chartUpdate` re-tints the same `<path>`
  elements and redraws the pins on every selection/mode change. Reuniting them
  would rebuild the SVG each time, and the `transition: fill` in `styles.css`
  only animates when the elements survive. `chartUpdate` returns a hidden span
  because a cell's value is its output slot — `chart` holds the real one.
- `makeTooltip(container)` is the shared hover tooltip for the map and the
  treemap. Do not go back to SVG `<title>`: it is delayed ~1s and unstyleable.
- The sidebar is two `.panel` boxes inside `.dash-side`: `.panel-mode` (the
  question) and `.panel-dc` (the inputs). Both option lists share the `.opt-list`
  row styling and the `.opt` / `.opt-name` / `.opt-meta` two-line markup, fed by
  the `format:` callback of `Inputs.radio` / `Inputs.checkbox`. `.dc-list` adds
  only the scroll cap. Keep the two lists visually identical — that parallel is
  the point.
- Nesting means the Quarto fences are deep: `.dash` is `::::::`, `.dash-side` and
  `.dash-main` are `:::::`, `.panel` is `::::`, `.opt-list` is `:::`. A child
  fence must be shorter than its parent, so adding a level means widening the
  ones above it.
- `d3` and `Inputs` come from Quarto's OJS stdlib — no `require` or import.
- Quarto emits one output div per top-level statement in an `{ojs}` block, but
  only DOM-valued cells render anything visible, so plain values and function
  declarations can sit anywhere without leaving inspector junk on the page.

### Verifying front-end changes without a browser

OJS runs only in the browser, so `quarto render` succeeding proves nothing about
the app. When a browser is unavailable, extract the cell bodies from `index.qmd`
and run them in Node against the real files in `data/processed/`, stubbing `html`
and the handful of `d3` functions used. Note that an OJS `name = { ... }` cell is
a *function body with an implicit return*, not an object literal, so it must be
wrapped as `(function(){ ... })()` before it will parse as JavaScript.

## Deployment

Pushing to `main` triggers `.github/workflows/publish.yml`: it renders with
Quarto and publishes `_site/` to `gh-pages` using a clean single-commit deploy.
GitHub Pages serves that branch from its root.

- The deploy **must** stay `clean: true, single-commit: true`. The branch
  previously shared history with `main` and inherited its `.gitignore`, whose
  `/site_libs/` rule silently excluded the Bootstrap CSS and the OJS runtime —
  the published page rendered as unstyled raw source. A wiped, historyless branch
  makes that class of bug impossible.
- If a deploy ever looks unstyled again, check
  `site_libs/quarto-ojs/quarto-ojs-runtime.js` on the live site first. A 404
  there is the tell.
- CI installs Quarto only, pinned to the version in the workflow. Keep it in
  sync with the local Quarto version so CI output matches local preview.
- The `origin` remote is HTTPS, but the local `gh` token lacks the `workflow`
  scope, so pushes touching `.github/workflows/` are rejected over HTTPS. Push
  over SSH (`git@github.com:jhelvy/datacenter-states.git`) instead.

## Data conventions

The core comparison is **average power in GW**. A state's average load is its
annual consumption ÷ 8,760 h (`mwh_to_avg_gw()` in `R/functions.R`); a data
center's announced capacity is already a continuous GW load. Keep both sides in
GW — never compare a capacity figure against an annual energy total.

Every row in `data/raw/datacenters.csv` carries a `source_url`, and
`validate_datacenters()` enforces the allowed `power_source` and `status` values.
`data/README.md` records provenance for every dataset; update it when sources
change.

# datacenter-states

A static Quarto website that makes the scale of AI data center power demand
tangible: pick one or more data centers and see the map light up the set of
U.S. states whose combined average electricity draw equals that same power.

- `R/` — data pipeline (EIA state power, map geometry, data center prep)
- `data/` — raw and processed datasets; see `data/README.md` for sources
- `index.qmd` (map/landing page) / `about.qmd` — the Quarto site pages
- `tests/testthat/` — tests for the R data pipeline

See `plan.md` for the implementation plan.

## Building the data

```r
source("R/build_data.R")
```

Then render the site with Quarto (`quarto render` / `quarto preview`).


## Deploying

Pushing to `main` triggers `.github/workflows/publish.yml`, which renders the
site with Quarto and publishes `_site/` to the `gh-pages` branch. GitHub Pages
serves that branch from its root.

CI runs Quarto only — it does not run R, because the pages contain no R chunks
and read their data from the committed files in `data/processed/`. When the
underlying data changes, run `source("R/build_data.R")` locally and commit the
regenerated `data/processed/` files along with your other changes.

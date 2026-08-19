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


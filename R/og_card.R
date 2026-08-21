# Build the 1200x630 social-share card. Run only when the card design changes;
# the resulting og-card.png is committed.
n <- 51; below <- 33
cols <- 17; size <- 34; gap <- 10
x0 <- 72; y0 <- 380
rects <- vapply(seq_len(n), function(i) {
  r <- (i - 1) %/% cols; c <- (i - 1) %% cols
  fill <- if (i <= below) "#2ca25f" else "#3d5566"
  sprintf('<rect x="%d" y="%d" width="%d" height="%d" rx="4" fill="%s"/>',
          x0 + c * (size + gap), y0 + r * (size + gap), size, size, fill)
}, character(1))

svg <- paste0(
  '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">\n',
  '<rect width="1200" height="630" fill="#12303f"/>\n',
  '<rect x="0" y="0" width="1200" height="8" fill="#2ca25f"/>\n',
  '<text x="72" y="190" font-family="Avenir Next, Helvetica Neue, Helvetica, sans-serif" ',
  'font-size="76" font-weight="700" fill="#ffffff">Data Centers vs. States</text>\n',
  '<text x="72" y="256" font-family="Avenir Next, Helvetica Neue, Helvetica, sans-serif" ',
  'font-size="34" fill="#9fb4bf">How much power do AI data centers really use?</text>\n',
  '<text x="72" y="308" font-family="Avenir Next, Helvetica Neue, Helvetica, sans-serif" ',
  'font-size="34" fill="#9fb4bf">See it next to whole U.S. states.</text>\n',
  paste(rects, collapse = "\n"), "\n",
  '<text x="72" y="600" font-family="Avenir Next, Helvetica Neue, Helvetica, sans-serif" ',
  'font-size="26" fill="#6f8a99">One 9.2 GW campus outdraws 33 states</text>\n',
  '</svg>\n')

tmp <- tempfile(fileext = ".svg")
writeLines(svg, tmp)
rsvg::rsvg_png(tmp, "og-card.png", width = 1200, height = 630)
cat("wrote og-card.png\n")

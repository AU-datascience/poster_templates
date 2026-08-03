#!/usr/bin/env Rscript

# WCAG contrast audit for the poster templates' color choices.
#
# Every foreground/background pair that actually occurs in the rendered output
# is checked against the WCAG 2.x thresholds: 4.5:1 (AA) and 7:1 (AAA) for
# normal-size text, 3:1 and 4.5:1 for large text (>=24px, or >=18.7px bold).
#
# Colors are read from source rather than restated here:
#   * palette variables    -- $... definitions in scss/poster-common.scss
#   * rule colors          -- `color:` / `background:` declarations in the
#                             stylesheets, including the banner's gradient
#                             stops, resolved through the palette
#   * print footer colors  -- footer-color / footer-text-color in each
#                             template's YAML
#
# So a re-color is genuinely re-audited. A missing selector or property is a
# hard error, not a silent pass -- if a class is renamed, this script fails
# and tells you which lookup broke.
#
# Usage (from the project root):
#   Rscript scripts/check-contrast.R                 # fail below AA
#   Rscript scripts/check-contrast.R --require-aaa   # fail below AAA
#
# This is the check to run if you fork the repo and re-color it. See
# "Re-coloring the templates" in README.md.

suppressPackageStartupMessages(library(tidyverse))

source("scripts/templates.R")
stop_unless_project_root()

COMMON_SCSS <- "scss/poster-common.scss"
TEMPLATE_SCSS <- c(
  "01" = "templates/01-classic-academic/classic-web.scss",
  "02" = "templates/02-modern-cards/modern-web.scss",
  "03" = "templates/03-minimal-story/minimal-web.scss"
)

# ---- WCAG math -------------------------------------------------------------

relative_luminance <- function(hex) {
  ch <- col2rgb(hex)[, 1] / 255
  ch <- if_else(ch <= 0.03928, ch / 12.92, ((ch + 0.055) / 1.055)^2.4)
  sum(ch * c(0.2126, 0.7152, 0.0722))
}

contrast_ratio <- function(fg, bg) {
  l <- sort(c(relative_luminance(fg), relative_luminance(bg)), decreasing = TRUE)
  (l[1] + 0.05) / (l[2] + 0.05)
}

# ---- Palette ---------------------------------------------------------------

# Values may be a hex literal ($au-navy: #25406A) or an alias to another
# variable ($link-color: $au-blue-text), so parse both and resolve aliases.
scss_lines <- function(path) readLines(path, warn = FALSE) |> str_remove("//.*$")

var_defs <- str_match(scss_lines(COMMON_SCSS),
                      "^\\s*(\\$[a-z0-9-]+)\\s*:\\s*(#[0-9A-Fa-f]{3,6}|\\$[a-z0-9-]+)\\s*;")
var_defs <- var_defs[!is.na(var_defs[, 1]), , drop = FALSE]
palette <- set_names(var_defs[, 3], var_defs[, 2])

for (i in seq_along(palette)) {
  aliases <- str_starts(palette, fixed("$"))
  if (!any(aliases)) break
  palette[aliases] <- palette[palette[aliases]]
}

required <- c("$au-navy", "$au-blue", "$au-blue-text", "$au-red", "$au-grey",
              "$body-bg", "$body-color", "$link-color")
unresolved <- required[!required %in% names(palette) |
                         !str_starts(palette[required] %||% "", fixed("#"))]
if (length(unresolved)) {
  stop("Could not resolve from ", COMMON_SCSS, ": ",
       paste(unresolved, collapse = ", "), call. = FALSE)
}

as_hex <- function(x) {
  x <- str_trim(x)
  if (str_starts(x, fixed("#"))) return(str_to_lower(x))
  # Named CSS colors that appear in these stylesheets (e.g. `background: white`).
  rgb(t(col2rgb(x)), maxColorValue = 255) |> str_to_lower()
}

resolve_vars <- function(value) {
  vars <- str_extract_all(value, "\\$[a-z0-9-]+")[[1]] |> unique()
  for (v in vars) {
    if (is.na(palette[v] %||% NA)) {
      stop("Stylesheet references undefined variable ", v, call. = FALSE)
    }
    value <- str_replace_all(value, fixed(v), palette[[v]])
  }
  value
}

# ---- Stylesheet rules ------------------------------------------------------

# A deliberately small SCSS reader: it tracks the current selector (including
# multi-line, comma-separated selector lists) and records color-valued
# declarations. It does not need to understand nesting beyond ignoring it,
# because every declaration audited here sits in a top-level rule.
parse_rules <- function(path) {
  lines <- scss_lines(path)
  out <- tibble(file = character(), selector = character(),
                property = character(), value = character())
  pending <- character()
  stack <- character()

  for (ln in lines) {
    trimmed <- str_trim(ln)
    if (trimmed == "" || str_starts(trimmed, fixed("/*"))) next

    if (str_detect(trimmed, "\\{\\s*$")) {
      selector <- str_trim(str_remove(trimmed, "\\{\\s*$"))
      full <- paste(c(pending, selector), collapse = " ")
      pending <- character()
      stack <- c(stack, full)
      next
    }
    if (str_starts(trimmed, fixed("}"))) {
      stack <- head(stack, -1)
      next
    }
    if (str_ends(trimmed, fixed(","))) {
      pending <- c(pending, trimmed)
      next
    }

    decl <- str_match(trimmed, "^([a-z-]+)\\s*:\\s*(.+);$")
    if (!is.na(decl[1]) && length(stack) &&
        decl[2] %in% c("color", "background", "background-color", "font-size")) {
      # A comma-separated selector list applies the declaration to each.
      selectors <- tail(stack, 1) |>
        str_split(",") |>
        unlist() |>
        str_trim() |>
        discard(~ .x == "")
      out <- bind_rows(out, tibble(file = path, selector = selectors,
                                  property = decl[2], value = decl[3]))
    }
  }
  out
}

rules <- map_dfr(c(COMMON_SCSS, TEMPLATE_SCSS), parse_rules)

# Pull the color(s) out of a declaration. `n = 2` is for the banner's
# linear-gradient, whose two stops are the two backgrounds text can sit on.
css_colors <- function(selector, property, file = NULL, n = 1) {
  hit <- rules |> filter(.data$selector == !!selector, .data$property == !!property)
  if (!is.null(file)) hit <- hit |> filter(.data$file == !!file)
  if (nrow(hit) == 0) {
    stop("No `", property, "` declaration found for selector `", selector, "`",
         if (!is.null(file)) paste0(" in ", file) else "",
         " -- was the class renamed?", call. = FALSE)
  }
  value <- resolve_vars(tail(hit$value, 1))

  found <- str_extract_all(value, "#[0-9A-Fa-f]{3,6}")[[1]]
  if (!length(found)) found <- str_extract(value, "^[a-z]+")
  found <- map_chr(found, as_hex)

  if (length(found) < n) {
    stop("Expected ", n, " color(s) in `", selector, " { ", property, " }` but found ",
         length(found), call. = FALSE)
  }
  head(found, n)
}

# WCAG's "large text" bar (3:1 / 4.5:1 instead of 4.5:1 / 7:1) starts at 24px,
# or 18.7px when bold. Where a rule declares its own size, read it rather than
# hardcoding the classification, so resizing a heading re-classifies its pair.
LARGE_TEXT_PX <- 24

css_font_size_px <- function(selector, file = NULL, root_px = 16) {
  hit <- rules |> filter(.data$selector == !!selector, .data$property == "font-size")
  if (!is.null(file)) hit <- hit |> filter(.data$file == !!file)
  if (nrow(hit) == 0) {
    stop("No `font-size` declaration found for selector `", selector, "`",
         if (!is.null(file)) paste0(" in ", file) else "", call. = FALSE)
  }
  value <- str_trim(tail(hit$value, 1))
  num <- as.numeric(str_extract(value, "[0-9.]+"))
  unit <- str_extract(value, "[a-z%]+$")
  if (is.na(num) || !unit %in% c("rem", "px")) {
    stop("Cannot interpret font-size `", value, "` for `", selector,
         "` -- expected rem or px.", call. = FALSE)
  }
  if (unit == "rem") num * root_px else num
}

banner_stops <- css_colors("header.quarto-title-block", "background", n = 2)
page_bg <- css_colors("body", "background")
card_bg <- css_colors("section.level2", "background", file = COMMON_SCSS)
ethics_bg <- css_colors(".ethics-panel", "background")

banner_title <- css_colors(".quarto-title-banner h1.title", "color")
meta_label <- css_colors(".quarto-title-meta-heading", "color")
meta_value <- css_colors(".quarto-title-meta-contents", "color")
acks_fg <- css_colors("#acknowledgments", "color")
h2_common <- css_colors("section.level2 > h2", "color", file = COMMON_SCSS)
h2_modern <- css_colors("section.level2 > h2", "color", file = TEMPLATE_SCSS[["02"]])
h2_minimal <- css_colors("section.level2 > h2", "color", file = TEMPLATE_SCSS[["03"]])
ethics_strong <- css_colors(".ethics-panel strong", "color")

h2_modern_large <- css_font_size_px("section.level2 > h2",
                                    file = TEMPLATE_SCSS[["02"]]) >= LARGE_TEXT_PX
h2_minimal_large <- css_font_size_px("section.level2 > h2",
                                     file = TEMPLATE_SCSS[["03"]]) >= LARGE_TEXT_PX
h2_classic_large <- css_font_size_px("section.level2 > h2",
                                     file = TEMPLATE_SCSS[["01"]]) >= LARGE_TEXT_PX

# ---- Pairs that occur in the output ----------------------------------------

# `large` marks text at >=24px (or >=18.7px bold), which WCAG holds to a lower
# bar. `source` records where the color came from, since Bootstrap-derived
# variables cannot be read out of a rule.
pairs <- tribble(
  ~context,                                  ~fg,             ~bg,             ~large, ~source,
  "body text on page background",            palette[["$body-color"]], page_bg,  FALSE, "Bootstrap var",
  "body text on white card",                 palette[["$body-color"]], card_bg,  FALSE, "Bootstrap var / rule",
  "h2 on white card (01)",                   h2_common,       card_bg,   h2_classic_large,  "rule",
  "h2 on page background (03, flat)",        h2_minimal,      page_bg,   h2_minimal_large,  "rule",
  "h2 accent on white card (02)",            h2_modern,       card_bg,   h2_modern_large,   "rule",
  "link on white card",                      palette[["$link-color"]], card_bg, FALSE, "Bootstrap var / rule",
  "link on page background",                 palette[["$link-color"]], page_bg, FALSE, "Bootstrap var / rule",
  "acks/refs text on page background",       acks_fg,         page_bg,          FALSE, "rule",
  # Bootstrap derives --bs-code-color from the brand grey, so every `inline
  # code` span in the templates (and there are many) is this pair.
  "inline code on white card",               palette[["$au-grey"]], card_bg,    FALSE, "Bootstrap var (--bs-code-color)",
  "inline code on page background",          palette[["$au-grey"]], page_bg,    FALSE, "Bootstrap var (--bs-code-color)",
  # The banner is a gradient, so its text is checked against BOTH stops.
  # Auditing only the dark stop is what originally hid a failure here.
  "banner title, dark stop",                 banner_title,    banner_stops[1],  TRUE,  "rule (gradient stop 1)",
  "banner title, light stop",                banner_title,    banner_stops[2],  TRUE,  "rule (gradient stop 2)",
  "banner meta label, dark stop",            meta_label,      banner_stops[1],  FALSE, "rule (gradient stop 1)",
  "banner meta label, light stop",           meta_label,      banner_stops[2],  FALSE, "rule (gradient stop 2)",
  "banner meta value, dark stop",            meta_value,      banner_stops[1],  FALSE, "rule (gradient stop 1)",
  "banner meta value, light stop",           meta_value,      banner_stops[2],  FALSE, "rule (gradient stop 2)",
  # No row for `.ethics-panel h2, .ethics-panel h3`: that rule is defensive
  # styling that currently matches nothing, because the panel's leads are
  # `**bold**` (rendered as <strong>) and the section's own h2 is a sibling of
  # the panel div, not a descendant. Verified against the rendered HTML. Add a
  # row here if a heading is ever placed inside the panel.
  "ethics panel strong text on cream",       ethics_strong,   ethics_bg,        FALSE, "rule",
  "ethics panel body text on cream",         palette[["$body-color"]], ethics_bg, FALSE, "Bootstrap var / rule"
)

# ---- Print footers, read from each template's YAML -------------------------

footer_pairs <- map_dfr(poster_templates, function(tpl) {
  qmd <- readLines(template_path(tpl), warn = FALSE)
  grab <- function(key) {
    hit <- str_match(qmd, paste0("^\\s*", key, ':\\s*"?([0-9A-Fa-f]{6})"?\\s*$'))
    hit[!is.na(hit[, 1]), 2][1]
  }
  bg <- grab("footer-color")
  if (is.na(bg)) return(NULL)
  # The extension's footer-text-color patch defaults to white when unset.
  fg <- grab("footer-text-color")

  tibble(
    context = paste0("print footer (", tpl$dir, ")"),
    fg = paste0("#", if (is.na(fg)) "ffffff" else fg) |> str_to_lower(),
    bg = paste0("#", bg) |> str_to_lower(),
    # Footer text is set at 30-40pt on a poster, comfortably "large".
    large = TRUE,
    source = "template YAML"
  )
})

# ---- Report ----------------------------------------------------------------

require_aaa <- "--require-aaa" %in% commandArgs(trailingOnly = TRUE)

results <- bind_rows(pairs, footer_pairs) |>
  mutate(
    # Palette values keep their authored case; lowercase everything so the
    # report doesn't mix #2F527A and #335986 styles.
    across(c(fg, bg), str_to_lower),
    ratio = map2_dbl(fg, bg, contrast_ratio),
    aa = if_else(large, 3, 4.5),
    aaa = if_else(large, 4.5, 7),
    level = case_when(ratio >= aaa ~ "AAA", ratio >= aa ~ "AA", TRUE ~ "FAIL"),
    ok = if (require_aaa) level == "AAA" else level != "FAIL"
  ) |>
  arrange(ratio)

options(width = 200)
results |>
  transmute(context, fg, bg, ratio = round(ratio, 2), aa, aaa, level, source) |>
  as.data.frame() |>
  print(row.names = FALSE, right = FALSE)

counts <- table(factor(results$level, levels = c("AAA", "AA", "FAIL")))
cat("\n", counts[["AAA"]], " AAA, ", counts[["AA"]], " AA only, ",
    counts[["FAIL"]], " failing",
    if (require_aaa) "  (--require-aaa: AA-only counts as failure)" else "",
    "\n\n", sep = "")

if (any(!results$ok)) quit(status = 1)

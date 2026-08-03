# Shared registry of the poster templates, sourced by the other helper
# scripts in this directory so that adding a template (or changing its column
# count) is a one-line edit in one place.
#
# `baseline_fill` is the per-column fill depth (percent of the content
# region's height reached by the lowest ink) measured from the shipped sample
# content. render-all.R fails if a column drops well below its baseline,
# which is the signature of a content edit emptying out a column.
#
# All helper scripts expect to be run from the project root (the directory
# holding _quarto.yml and templates/).

poster_templates <- list(
  list(
    dir = "01-classic-academic",
    label = "01-classic-academic",
    size = "42x28in, 3 columns",
    num_columns = 3,
    # Re-measured 2026-08-03 after enlarging the header logo (institution-logo
    # swapped to images/au-logo-hires.png). Kept deliberately small here
    # (univ-logo-column-size: 2) because this template runs with ~0 slack --
    # anything larger overflowed to a second page.
    baseline_fill = c(100, 100, 82)
  ),
  list(
    dir = "02-modern-cards",
    label = "02-modern-cards",
    size = "48x36in, 2 columns",
    num_columns = 2,
    # Column 1 is intentionally short; see the #colbreak() note in its .qmd.
    # Re-measured 2026-08-03 after enlarging the header logo (institution-logo
    # swapped to the higher-res images/au-logo-hires.png, univ-logo-column-size
    # 3.5in), widening the ethics-panel box to 49% (computed against the
    # page's *printable* width -- see the comment above the #place() call --
    # to actually match column 2's net width, and its text bumped to
    # body-font-size), and replacing the 72pt headline `.stat` block with one
    # plain-markdown sentence at body size -- column 1 lost the extra height
    # that oversized block used to hold, so its fill dropped 50 -> 44; column
    # 2 (the #colbreak() side) is unaffected.
    baseline_fill = c(44, 86)
  ),
  list(
    dir = "03-minimal-story",
    label = "03-minimal-story",
    size = "24x52in, 1 column",
    num_columns = 1,
    # Re-measured 2026-08-03 after enlarging the header logo (institution-logo
    # swapped to images/au-logo-hires.png) and widening the ethics-panel box
    # from 34% to 83% (to match the single column's net width); this template
    # has plenty of vertical slack so the drift is small either way.
    baseline_fill = 77
  )
)

template_path <- function(tpl, ext = "qmd") {
  file.path("templates", tpl$dir, paste0("poster.", ext))
}

stop_unless_project_root <- function() {
  if (!dir.exists("templates") || !file.exists("_quarto.yml")) {
    stop("Run this script from the project root (the folder with _quarto.yml).",
         call. = FALSE)
  }
}

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
    baseline_fill = c(100, 100, 82)
  ),
  list(
    dir = "02-modern-cards",
    label = "02-modern-cards",
    size = "48x36in, 2 columns",
    num_columns = 2,
    # Column 1 is intentionally short; see the #colbreak() note in its .qmd.
    baseline_fill = c(44, 82)
  ),
  list(
    dir = "03-minimal-story",
    label = "03-minimal-story",
    size = "24x52in, 1 column",
    num_columns = 1,
    baseline_fill = 79
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

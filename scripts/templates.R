# Shared registry of the poster templates, sourced by the other helper
# scripts in this directory so that adding a template (or changing its column
# count) is a one-line edit in one place.
#
# Paths are resolved with `here::here()`, anchored at the project root (the
# directory holding `.here` / `_quarto.yml` / `.git`), rather than by
# requiring the caller to `setwd()` into the project first. That means every
# script in this directory can be run from any working directory --
# `Rscript path/to/scripts/render-all.R` works the same from anywhere, and
# sourcing these files from an R session started elsewhere works too.
#
# Poster discovery supports two repo layouts:
#   * multi-template (this repo, as shipped): templates/<dir>/<name>.qmd,
#     exactly one .qmd per subdirectory, filename not assumed to be
#     "poster.qmd"
#   * single-poster fork: no templates/ directory at all -- just one .qmd
#     sitting at the project root, under whatever name the user gave it
#
# `baseline_fill` below is the per-column fill depth (percent of the content
# region's height reached by the lowest ink) measured from the shipped sample
# content, keyed by directory name. render-all.R fails if a *known* template
# drops well below its baseline, which is the signature of a content edit
# emptying out a column. A template discovered under a name/location that
# isn't in this list (e.g. a renamed single-poster fork) has no registered
# baseline, so render-all.R treats its balance numbers as informational only
# rather than failing on them.

suppressPackageStartupMessages(library(here))

known_template_meta <- list(
  "01-classic-academic" = list(
    size = "42x28in, 3 columns",
    # Re-measured 2026-08-04 after pinning "Source Sans 3"/"STIX Two Text" as
    # brand font resources in _brand.yml (see AGENTS.md's former "Fonts --
    # unresolved" note): 100/100/81.9, a trivial shift from the prior
    # 100/100/82 baseline (itself measured 2026-08-03 after enlarging the
    # header logo). This template runs with ~0 slack -- anything taller than
    # the current header logo (univ-logo-column-size: 2) overflows to a
    # second page.
    baseline_fill = c(100, 100, 82)
  ),
  "02-modern-cards" = list(
    size = "48x36in, 2 columns",
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
    #
    # Re-measured again 2026-08-04 after pinning "Source Sans 3"/"STIX Two
    # Text" as brand font resources in _brand.yml: 42.2/86.4, essentially
    # unchanged.
    baseline_fill = c(42, 86)
  ),
  "03-minimal-story" = list(
    size = "24x52in, 1 column",
    # Re-measured 2026-08-03 after enlarging the header logo (institution-logo
    # swapped to images/au-logo-hires.png) and widening the ethics-panel box
    # from 34% to 83% (to match the single column's net width); this template
    # has plenty of vertical slack so the drift is small either way.
    #
    # Re-measured again 2026-08-04 after pinning "Source Sans 3"/"STIX Two
    # Text" as brand font resources in _brand.yml: 78.1.
    baseline_fill = 78
  )
)

project_root <- function() here::here()

#' Read `num-columns:` out of a poster's `format: poster-typst:` YAML block,
#' rather than hardcoding it a second time in this registry.
read_num_columns <- function(qmd_path) {
  lines <- readLines(qmd_path, warn = FALSE)
  hit <- grep("^\\s*num-columns\\s*:\\s*[0-9]+\\s*$", lines, value = TRUE)
  if (!length(hit)) {
    stop("Could not find `num-columns:` in ", qmd_path,
         " (expected under format: poster-typst:).", call. = FALSE)
  }
  as.integer(gsub("\\D", "", hit[[1]]))
}

#' Discover poster .qmd file(s) and assemble the template registry.
#'
#' Prefers the multi-template layout (templates/<dir>/*.qmd). Falls back to
#' treating the project root itself as a single template if no templates/
#' directory exists, so a fork that keeps only one poster -- renamed and/or
#' moved to the top level -- still works without editing this file.
discover_poster_templates <- function() {
  root <- project_root()
  templates_dir <- file.path(root, "templates")

  if (dir.exists(templates_dir)) {
    subdirs <- list.dirs(templates_dir, recursive = FALSE)
    if (!length(subdirs)) {
      stop("templates/ exists but contains no subdirectories.", call. = FALSE)
    }
    return(lapply(subdirs, function(d) {
      qmds <- list.files(d, pattern = "\\.qmd$", full.names = TRUE)
      if (length(qmds) != 1) {
        stop("Expected exactly one .qmd in ", d, ", found ", length(qmds), ".",
             call. = FALSE)
      }
      dir_name <- basename(d)
      meta <- known_template_meta[[dir_name]]
      list(
        dir = dir_name,
        label = dir_name,
        file = qmds[[1]],
        num_columns = read_num_columns(qmds[[1]]),
        size = if (is.null(meta)) NA_character_ else meta$size,
        baseline_fill = if (is.null(meta)) NA_real_ else meta$baseline_fill
      )
    }))
  }

  # Single-poster layout: no templates/ directory, so the poster is whatever
  # single .qmd sits at the project root, under any filename.
  qmds <- list.files(root, pattern = "\\.qmd$", full.names = TRUE)
  if (!length(qmds)) {
    stop("No .qmd file found under ", root,
         " and no templates/ directory either -- nothing to render/check.",
         call. = FALSE)
  }
  if (length(qmds) > 1) {
    stop("Multiple .qmd files found at the project root (",
         paste(basename(qmds), collapse = ", "),
         "); move each into its own templates/<name>/ subdirectory so this ",
         "registry knows which is which.", call. = FALSE)
  }
  dir_name <- tools::file_path_sans_ext(basename(qmds[[1]]))
  list(list(
    dir = dir_name,
    label = dir_name,
    file = qmds[[1]],
    num_columns = read_num_columns(qmds[[1]]),
    size = NA_character_,
    baseline_fill = NA_real_
  ))
}

poster_templates <- discover_poster_templates()

# `tpl$file` is already an absolute, fully-resolved path (via here::here()),
# so ext-swapping is just a suffix swap rather than another file.path() build
# off an assumed "poster" basename.
template_path <- function(tpl, ext = "qmd") {
  if (ext == "qmd") return(tpl$file)
  sub("\\.qmd$", paste0(".", ext), tpl$file)
}

#' Sanity check before doing any file I/O with root-relative paths built by
#' hand. Not required for discover_poster_templates() itself (here::here()
#' finds the root on its own regardless of cwd), but a cheap guard against
#' `here` picking an unexpected root (e.g. no .here/.git/_quarto.yml anywhere
#' in the path, or a stray .git higher up the tree).
stop_unless_project_root <- function() {
  root <- project_root()
  if (!file.exists(file.path(root, "_quarto.yml"))) {
    stop("Could not find _quarto.yml at the project root here::here() ",
         "resolved to (", root, "). If that's the wrong directory, add an ",
         "empty `.here` file at the intended project root.", call. = FALSE)
  }
}

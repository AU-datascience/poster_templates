#!/usr/bin/env Rscript

# Regenerates the README's preview images from the rendered poster PDFs:
#
#   images/previews/preview-<template>.png   1200px wide, one per template
#   comparison.png                           2000px wide, the three stacked
#
# Neither is produced by `quarto render`, so run this after any content edit
# (and re-render the PDFs first -- scripts/render-all.R does both in order).
#
# Usage (from the project root):
#   Rscript scripts/make-previews.R

suppressPackageStartupMessages({
  library(tidyverse)
  library(magick)
})

source("scripts/templates.R")
stop_unless_project_root()

# Rasterize at 2x the target width and let magick downsample, which is much
# cheaper than the old "render at 300 dpi then shrink" recipe (a 48x36in page
# at 300 dpi is a 14400x10800 bitmap) and visually indistinguishable at these
# display sizes.
render_at_width <- function(pdf_path, target_px, supersample = 2) {
  width_in <- pdftools::pdf_pagesize(pdf_path)$width[[1]] / 72
  image_read(pdftools::pdf_render_page(
    pdf_path, page = 1, dpi = target_px * supersample / width_in
  ))
}

dir.create("images/previews", recursive = TRUE, showWarnings = FALSE)

rows <- map(poster_templates, function(tpl) {
  pdf_path <- template_path(tpl, "pdf")
  if (!file.exists(pdf_path)) {
    stop("Missing ", pdf_path, " -- render the poster first.", call. = FALSE)
  }

  render_at_width(pdf_path, 1200) |>
    image_resize("1200x") |>
    image_write(file.path("images/previews", paste0("preview-", tpl$dir, ".png")))

  message("wrote images/previews/preview-", tpl$dir, ".png")

  # Rows rather than side-by-side columns: 03-minimal-story is a tall
  # portrait banner, so matching heights would shrink it to a sliver.
  render_at_width(pdf_path, 2000) |>
    image_resize("2000x") |>
    image_border("white", "0x64") |>
    image_annotate(paste0(tpl$label, " (", tpl$size, ")"),
                   size = 44, gravity = "north", color = "#25406A",
                   weight = 700)
})

do.call(c, rows) |>
  image_append(stack = TRUE) |>
  image_write("comparison.png")

message("wrote comparison.png")

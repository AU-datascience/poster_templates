#!/usr/bin/env Rscript

# Column balance check for the Typst poster templates.
#
# Rasterizes a rendered poster PDF and measures, for each column band, how
# much of the column's vertical extent is actually used. Its purpose is to
# catch the failure mode these templates are prone to: after a content edit,
# Typst's column flow leaves a trailing column (or the bottom of one) empty,
# so the poster looks lopsided even though it renders without error.
#
# Usage (from the project root):
#   Rscript scripts/check-column-balance.R <poster.pdf> <num-columns> [dpi]
#
# Or source it and call poster_balance() / report_balance() -- which is what
# scripts/render-all.R does. Set POSTER_HELPERS_SOURCED before sourcing to
# suppress the command-line behavior.
#
# Interpretation: `fill_pct` is where the lowest ink in that column sits, as a
# share of the content region's height. The bottom-right ethics box is placed
# outside column flow, so it inflates the last column -- see
# `fill_pct_excl_box`, which blanks that corner out.
#
# Baselines for the shipped sample content live in scripts/templates.R. They
# are accepted slack (the samples are deliberately light on text); a *drop*
# from those numbers after a content edit is the signal to look at.

suppressPackageStartupMessages(library(tidyverse))

# Returns one row per column: ink coverage plus how far down the column the
# lowest ink sits, with and without the out-of-flow ethics box.
poster_balance <- function(pdf_path, n_col, dpi = 40) {
  page <- pdftools::pdf_render_page(pdf_path, page = 1, dpi = dpi, numeric = TRUE)
  gray <- apply(page[, , 1:3, drop = FALSE], c(1, 2), mean)
  ink <- gray < 0.95

  n_row <- nrow(ink)
  n_px <- ncol(ink)

  # Header and footer are full-bleed bands (solid colored bars), so find them
  # as rows that are almost entirely inked and trim the content region to
  # whatever lies between them.
  band_rows <- which(rowMeans(ink) > 0.9)
  top_band <- band_rows[band_rows < n_row * 0.3]
  bot_band <- band_rows[band_rows > n_row * 0.8]
  content_top <- if (length(top_band)) max(top_band) + 1L else round(n_row * 0.12)
  content_bot <- if (length(bot_band)) min(bot_band) - 1L else round(n_row * 0.95)

  content <- ink[content_top:content_bot, , drop = FALSE]
  content_h <- nrow(content)

  # The ethics callout is pinned bottom-right outside the column flow, so it
  # would otherwise register as content filling the final column.
  content_no_box <- content
  content_no_box[round(content_h * 0.82):content_h, round(n_px * 0.58):n_px] <- FALSE

  edges <- round(seq(1, n_px + 1, length.out = n_col + 1))

  fill_depth <- function(m) {
    rows <- which(rowSums(m) > 0)
    if (!length(rows)) return(0)
    max(rows) / nrow(m) * 100
  }

  map_dfr(seq_len(n_col), function(i) {
    cols <- edges[i]:(edges[i + 1] - 1)
    tibble(
      column = i,
      ink_pct = round(mean(content[, cols, drop = FALSE]) * 100, 1),
      fill_pct = round(fill_depth(content[, cols, drop = FALSE]), 1),
      fill_pct_excl_box = round(fill_depth(content_no_box[, cols, drop = FALSE]), 1)
    )
  })
}

report_balance <- function(pdf_path, n_col, dpi = 40) {
  balance <- poster_balance(pdf_path, n_col, dpi)

  cat("\n", basename(dirname(pdf_path)), " (", n_col, " column(s))\n", sep = "")
  print(as.data.frame(balance), row.names = FALSE)

  spread <- diff(range(balance$fill_pct_excl_box))
  sparse <- balance |> filter(fill_pct_excl_box < 70)

  if (n_col > 1) {
    cat("\nfill spread across columns:", round(spread, 1), "points\n")
    if (nrow(sparse)) {
      cat("NOTE: column(s)", paste(sparse$column, collapse = ", "),
          "below 70% fill -- expected for some templates; compare against",
          "the baselines in scripts/templates.R\n")
    } else if (spread > 15) {
      cat("NOTE: columns differ by more than 15 points of fill\n")
    } else {
      cat("Columns are reasonably balanced.\n")
    }
  } else {
    cat("\nSingle column; content ends at", balance$fill_pct_excl_box[[1]],
        "% of the content height.\n")
  }
  cat("\n")

  invisible(balance)
}

if (!exists("POSTER_HELPERS_SOURCED")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    stop("Usage: check-column-balance.R <poster.pdf> <num-columns> [dpi]")
  }
  report_balance(
    args[[1]],
    as.integer(args[[2]]),
    if (length(args) >= 3) as.numeric(args[[3]]) else 40
  )
}

#!/usr/bin/env Rscript

# Renders every poster template to both formats and runs regression checks on
# the output. Each check exists because the corresponding failure happened
# once and was invisible in the render log:
#
#   pages           a content edit silently overflowing onto a second Typst
#                   page (a poster must be exactly one page)
#   divider         the web section divider disappearing from the HTML
#   acknowledgments raw HTML inside a .content-visible div swallowing every
#                   later element in the Typst output, so the acknowledgments,
#                   grant number, and References heading vanished from print
#                   while the web version looked fine
#   ethics          the Ethics & Broader Impact panel missing from either format
#   balance         a column emptying out relative to its measured baseline
#   heading rule    a `####` heading placed before the level-3 show rule, so
#                   it silently keeps the package's "1) Heading:" run-in style
#   contrast        a palette edit dropping a color below WCAG AA
#                   (delegated to scripts/check-contrast.R)
#
# Usage (from the project root):
#   Rscript scripts/render-all.R            # render, then check
#   Rscript scripts/render-all.R --no-render  # check existing output only
#
# Exits non-zero if any check fails, so it can be wired into CI or a
# pre-commit hook.

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

POSTER_HELPERS_SOURCED <- TRUE
source(here::here("scripts", "templates.R"))
source(here::here("scripts", "check-column-balance.R"))
stop_unless_project_root()

do_render <- !("--no-render" %in% commandArgs(trailingOnly = TRUE))

# The grant number stands in for the whole acknowledgments block: it is the
# last thing before the References heading, so if it made it into the PDF, the
# tail of the document did too.
GRANT <- "BJME-2026-014"

render_template <- function(tpl) {
  message("rendering ", tpl$dir, " ...")
  # Capture rather than discard output: a render failure with nothing printed
  # is undiagnosable (this bit us once in CI -- the render step failed with
  # no clue why until this was added).
  out <- suppressWarnings(
    system2("quarto", c("render", shQuote(template_path(tpl))),
            stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  if (status != 0) {
    message("---- quarto render output for ", tpl$dir, " ----")
    message(paste(out, collapse = "\n"))
    message("---- end quarto render output ----")
  }
  tibble(check = "render", ok = status == 0,
         detail = if (status == 0) "both formats" else paste("exit", status))
}

# Fast percent-decoder for the `data:text/css,...` URIs `embed-resources:
# true` produces. base R's utils::URLdecode() is quadratic on strings this
# long (it hung indefinitely on a ~3.8MB encoded font payload during testing)
# -- this splits on literal `%` once and vectorizes the hex-to-byte
# conversion instead, which is linear and takes well under a second per file.
fast_url_decode <- function(x) {
  parts <- strsplit(x, "%", fixed = TRUE)[[1]]
  if (length(parts) <= 1) return(x)
  head <- parts[1]
  tail_parts <- parts[-1]
  hex <- substr(tail_parts, 1, 2)
  rest <- substr(tail_parts, 3, nchar(tail_parts))
  bytes <- strtoi(hex, base = 16L)
  chars <- rawToChar(as.raw(bytes), multiple = TRUE)
  paste0(head, paste0(chars, rest, collapse = ""))
}

# Returns every bit of CSS actually delivered in a rendered HTML file: literal
# `<style>` blocks *and* the decoded contents of any `<link href="data:text/
# css,...">` (what `embed-resources: true` uses to inline stylesheets, rather
# than a `<link rel="stylesheet">` pointing at a separate file).
#
# This distinction matters: a plain string search for "@font-face" or
# "fonts.googleapis.com" against the raw file is a false negative whenever
# the CSS is delivered percent-encoded like this -- exactly what happened
# when this project's own web fonts were first (mis)diagnosed as not being
# delivered at all. See AGENTS.md's "Fonts" section for the full story.
#
# Uses fixed-string/useBytes searches throughout rather than backtracking
# regex or character-aware substring() over the whole (multi-MB, embedded
# base64 font data) file, both of which are slow enough on files this size to
# look like a hang rather than an error.
rendered_css_text <- function(html_path) {
  raw <- readBin(html_path, "raw", file.info(html_path)$size)
  html <- rawToChar(raw)
  Encoding(html) <- "bytes"

  style_starts <- gregexpr("<style", html, fixed = TRUE, useBytes = TRUE)[[1]]
  style_texts <- character(0)
  if (style_starts[1] != -1) {
    for (s in style_starts) {
      tag_end <- regexpr(">", substring(html, s), fixed = TRUE, useBytes = TRUE)
      if (tag_end == -1) next
      body_start <- s + tag_end
      close <- regexpr("</style>", substring(html, body_start), fixed = TRUE, useBytes = TRUE)
      if (close == -1) next
      style_texts <- c(style_texts, substring(html, body_start, body_start + close - 2))
    }
  }

  needle <- 'href="data:text/css,'
  link_starts <- gregexpr(needle, html, fixed = TRUE, useBytes = TRUE)[[1]]
  css_links <- character(0)
  if (link_starts[1] != -1) {
    for (s in link_starts) {
      body_start <- s + nchar(needle, type = "bytes")
      close <- regexpr('"', substring(html, body_start), fixed = TRUE, useBytes = TRUE)
      if (close == -1) next
      encoded <- substring(html, body_start, body_start + close - 2)
      css_links <- c(css_links, fast_url_decode(encoded))
    }
  }

  paste(c(style_texts, css_links), collapse = "\n")
}

# Confirms the brand web font is both fetched (a self-hosted `@font-face`,
# not a bare family name that would silently fall back to a system font) and
# actually applied (the Bootstrap variable Quarto's brand-aware theming
# derives it into). Hardcodes "Source Sans 3" rather than reading it out of
# `_brand.yml` -- consistent with how check-contrast.R reads its palette
# expectations, and there's currently just the one web-facing brand font
# (STIX Two Text is declared only for Typst's print body; see AGENTS.md).
check_fonts <- function(tpl) {
  html_path <- template_path(tpl, "html")
  if (!file.exists(html_path)) {
    return(tibble(check = "web fonts (brand)", ok = FALSE, detail = "html missing"))
  }

  css <- rendered_css_text(html_path)
  has_face <- str_detect(css, regex("@font-face\\s*\\{[^}]*font-family:\\s*'Source Sans 3'"))
  has_var  <- str_detect(css, regex("--bs-body-font-family:\\s*Source Sans 3"))

  tibble(
    check = "web fonts (brand)",
    ok = has_face && has_var,
    detail = paste0("@font-face embedded: ", has_face,
                     "; --bs-body-font-family set: ", has_var)
  )
}

# Source-level check: Typst show rules only affect content that follows them,
# so a `####` heading above the rule silently keeps the package's numbered
# italic run-in style.
check_heading_rule <- function(tpl) {
  qmd <- readLines(template_path(tpl), warn = FALSE)
  rule_at <- str_which(qmd, fixed("#show heading.where(level: 3)"))
  h4_at <- str_which(qmd, "^#### ")
  early <- if (length(rule_at)) h4_at[h4_at < min(rule_at)] else h4_at

  tibble(
    check = "#### after show rule",
    ok = length(rule_at) >= 1 && length(early) == 0,
    detail = case_when(
      !length(rule_at) ~ "show rule missing",
      length(early) > 0 ~ paste0(length(early), " heading(s) before rule: line(s) ",
                                 paste(early, collapse = ", ")),
      .default = paste(length(h4_at), "heading(s), all after rule")
    )
  )
}

check_template <- function(tpl) {
  pdf_path <- template_path(tpl, "pdf")
  html_path <- template_path(tpl, "html")

  if (!file.exists(pdf_path) || !file.exists(html_path)) {
    return(tibble(check = "output exists", ok = FALSE, detail = "missing pdf/html"))
  }

  pdf_txt <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  n_pages <- pdftools::pdf_info(pdf_path)$pages
  html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
  n_divider <- str_count(html, fixed('<hr class="section-divider">'))

  balance <- poster_balance(pdf_path, tpl$num_columns)

  # A template discovered outside the known registry (see
  # scripts/templates.R -- e.g. a renamed single-poster fork) has no
  # measured baseline to compare against, so report the numbers without
  # failing on them.
  has_baseline <- !anyNA(tpl$baseline_fill)
  shortfall <- if (has_baseline) tpl$baseline_fill - balance$fill_pct_excl_box else NA_real_
  balance_check <- if (has_baseline) {
    # Tolerance of 10 points absorbs rasterization jitter and small edits;
    # a column going properly empty drops far more than that.
    tibble(check = "column balance", ok = all(shortfall <= 10),
           detail = paste0(paste(balance$fill_pct_excl_box, collapse = "/"),
                           " vs baseline ",
                           paste(tpl$baseline_fill, collapse = "/")))
  } else {
    tibble(check = "column balance", ok = TRUE,
           detail = paste0(paste(balance$fill_pct_excl_box, collapse = "/"),
                           " (no baseline registered -- informational only)"))
  }

  bind_rows(
    tibble(check = "pages", ok = n_pages == 1,
           detail = paste(n_pages, "page(s)")),
    tibble(check = "divider (html)", ok = n_divider == 1,
           detail = paste(n_divider, "occurrence(s)")),
    tibble(check = "acknowledgments (pdf)",
           ok = str_detect(pdf_txt, "Acknowledgments") &&
                str_detect(pdf_txt, fixed(GRANT)),
           detail = if (str_detect(pdf_txt, fixed(GRANT))) "heading + grant no." else "MISSING"),
    tibble(check = "references heading (pdf)",
           ok = str_detect(pdf_txt, "References"), detail = ""),
    tibble(check = "ethics panel (both)",
           ok = str_detect(html, "ethics-panel") &&
                str_detect(pdf_txt, "Ethics & Broader Impact"),
           detail = ""),
    balance_check,
    check_heading_rule(tpl),
    check_fonts(tpl)
  )
}

# The contrast audit is project-wide (one shared palette), not per template, so
# it runs once. Delegated to its own script rather than duplicated, so it stays
# usable standalone while a single `render-all.R` still covers every check.
run_contrast_audit <- function() {
  out <- suppressWarnings(
    system2("Rscript", here::here("scripts", "check-contrast.R"),
            stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status") %||% 0

  cat("\n", paste(out, collapse = "\n"), "\n", sep = "")

  tibble(template = "(project)", check = "contrast (WCAG AA)", ok = status == 0,
         detail = str_trim(tail(out[str_trim(out) != ""], 1)))
}

results <- bind_rows(
  map_dfr(poster_templates, function(tpl) {
    rendered <- if (do_render) render_template(tpl) else NULL
    bind_rows(rendered, check_template(tpl)) |>
      mutate(template = tpl$dir, .before = 1)
  }),
  run_contrast_audit()
)

cat("\n")
# Keep the results table on one line per check rather than letting print()
# wrap the detail column into a separate block.
options(width = 200)
results |>
  mutate(result = if_else(ok, "PASS", "FAIL")) |>
  select(template, check, result, detail) |>
  as.data.frame() |>
  print(row.names = FALSE, right = FALSE)

n_fail <- sum(!results$ok)
cat("\n", nrow(results) - n_fail, " passed, ", n_fail, " failed\n\n", sep = "")

if (n_fail > 0) {
  quit(status = 1)
}

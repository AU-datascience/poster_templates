#!/usr/bin/env bash
# Pre-render hook (see docs-src/_quarto.yml's `project: pre-render:`).
#
# GitHub Pages serves only the committed /docs folder (Settings -> Pages:
# branch main, /docs) -- it has no visibility into the repo root. The
# template previews and comparison.png that used to be referenced as
# "../images/..." from docs-src/*.qmd would 404 once deployed (and, as it
# turns out, in `quarto preview`/`quarto render` too, since the dev server
# and the copied-resource resolution are also scoped to the project/output
# tree and don't reach outside it via `../`).
#
# So: copy the canonical images from the repo root into docs-src/images/
# before every render, and reference them from the .qmd files as
# "images/..." (no "../"), a normal project-relative path. Quarto then
# carries them into ../docs/images/ alongside the rendered HTML like any
# other referenced image, making the published site fully self-contained.
#
# docs-src/images/ itself is gitignored -- it's a copy, regenerated here,
# not a second source of truth. Re-run `Rscript scripts/make-previews.R` at
# the repo root first if you want the previews to reflect a content change.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

mkdir -p images/previews
cp ../images/previews/preview-01-classic-academic.png images/previews/
cp ../images/previews/preview-02-modern-cards.png images/previews/
cp ../images/previews/preview-03-minimal-story.png images/previews/
cp ../comparison.png images/comparison.png

# Quarto Conference Posters

**Full documentation: <https://au-datascience.github.io/poster_templates/>**

If you want to make a conference-style large-format poster using Quarto, this site has working templates for different style posters.

- The workflow uses Quarto and its `poster-typst` extension as a modern replacement for older `posterdown`/R Markdown poster workflows. 
- The workflow also uses Quarto's `_brand.yml` file to provide for consistent theming.
- Forking the repo allows you to access the templates and the supporting tools/scripts to check compliance.

> **Caveat:** Quarto's its `poster-typst` extension and `_brand.yml` theming are both still under active development. Several items in [Notes / gotchas](scripts-and-ci.qmd#notes-gotchas) describe current rough edges (local patches, path handling, caching) that a future Quarto/Typst release may resolve outright. If something documented here seems to have changed, check the current Quarto release notes before assuming the workaround is still needed. 

There are three templates; each a single `.qmd` file that renders to **two** outputs -- a large-format print PDF via [Typst](https://typst.app), and a responsive HTML "web poster" -- from the same content in one pass.

![Comparison of the three print posters, one per row](comparison.png)

## Quickstart

1. Fork or clone this repo.
2. Copy one of the `templates/*/` folders (e.g. `cp -r templates/01-classic-academic templates/my-poster`) and edit its `poster.qmd`.
3. `quarto render templates/my-poster/poster.qmd` -- check `poster.pdf` and `poster.html`.
4. `Rscript scripts/render-all.R` to render + check every template for known regressions before you call it done.

The full walkthrough (including re-coloring for a different organization, choosing a print size for a specific conference, and what each script/CI check does) is on the [documentation site](https://au-datascience.github.io/poster_templates/) -- start on the [Home](https://au-datascience.github.io/poster_templates/) page.

## Requirements

**To render a poster itself:** [Quarto](https://quarto.org) (a version at or near the one pinned in [`.quarto-version`](.quarto-version)) and R -- every template's R code chunks are part of the *shipped example content*, not the poster mechanism itself, so if you replace the demo analysis with your own R or Python code, only your own code's package requirements apply. As shipped, the three example posters use:

- `tidyverse`, `palmerpenguins`, `patchwork` (all three templates)
- `broom` (`01-classic-academic` only, for `broom::tidy()` model summaries)
- `knitr` (all three, for `knitr::kable()` tables -- normally auto-loaded by Quarto's R engine, listed here for completeness)

No Python packages are required unless you add your own Python chunks. No system libraries beyond a working R + Quarto install are needed for the print or web render themselves; fonts (`Source Sans 3`, `STIX Two Text`) are fetched from Google and cached by Quarto at render time (see [`AGENTS.md`](AGENTS.md)'s "Fonts" section), not installed as system fonts.

**To run the helper scripts in `scripts/`:** all four use `tidyverse` and `here`; `make-previews.R` additionally needs `magick` (which needs the ImageMagick system library), and `check-column-balance.R` needs `pdftools` (which needs the poppler system library). `check-contrast.R` needs only `tidyverse`/`here` -- it's pure source/CSS parsing, no rendering. None of the scripts are required to render a poster; `quarto render templates/<name>/poster.qmd` alone is enough. They exist to catch regressions (see [Scripts & CI](https://au-datascience.github.io/poster_templates/scripts-and-ci.html)), and CI (`.github/workflows/posters.yml`) installs all of the above automatically via `r-lib/actions/setup-r-dependencies`, so you never need to install anything by hand just to see CI pass on a fork.

**Is this an `renv` repo?** No, deliberately not. `renv` buys strict, pinned reproducibility of exact package versions, at the cost of a lockfile contributors must keep in sync and an `renv::restore()` step before anything runs. For a small, stable package list on a repo meant to be forked and heavily edited by students building their own poster content (who will be adding whatever packages *their* analysis needs, not constrained by a lockfile), that friction outweighs the benefit here. If you want tighter reproducibility for your own fork -- e.g. pinning exact versions for a class where everyone must get identical output -- `renv::init()` after cloning is a reasonable thing to layer on yourself; it just isn't part of this template.

## Site map

| Page | Covers |
|---|---|
| [Home](https://au-datascience.github.io/poster_templates/) | Repo structure, forking and building your own poster |
| [Templates](https://au-datascience.github.io/poster_templates/templates.html) | The three template designs, and choosing a print size |
| [Content Guide](https://au-datascience.github.io/poster_templates/content-guide.html) | The Ethics & Broader Impact panel, shared resources (`_brand.yml`, `references.bib`, logo) |
| [Theming & Brand](https://au-datascience.github.io/poster_templates/theming.html) | Re-coloring the templates and WCAG contrast auditing; how `_brand.yml` fits in |
| [Scripts & CI](https://au-datascience.github.io/poster_templates/scripts-and-ci.html) | The R build/check scripts, the `Makefile`, continuous integration, and Notes / gotchas |
| [Why Typst?](https://au-datascience.github.io/poster_templates/why-typst.html) | Why print renders through Typst instead of LaTeX, and the trade-offs |

This site's source is [`docs-src/`](docs-src/) (a nested Quarto website project); it renders to `docs/`, which GitHub Pages serves directly (Settings -> Pages: branch main, `/docs`). [`.github/workflows/docs.yml`](.github/workflows/docs.yml) renders `docs-src/` fresh on push/PR and fails if the result doesn't match the committed `docs/` -- it does not publish anything itself, since committing a fresh `quarto render docs-src` output to `docs/` *is* the deploy step; the check just catches someone forgetting to do that before merging. This is separate from [`.github/workflows/posters.yml`](.github/workflows/posters.yml), which renders and checks the poster templates themselves.

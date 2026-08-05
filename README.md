# Quarto Conference Posters

**Full documentation: <https://au-datascience.github.io/poster_templates/>**

If you want to make a conference-style large-format poster using Quarto, this site has working templates for different style posters.

- The workflow uses Quarto and its `poster-typst` extension as a modern replacement for older `posterdown`/R Markdown poster workflows. 
- The workflow also uses Quarto's `_brand.yml` file to provide for consistent theming.
- Forking the repo allows you to access the templates and the supporting tools/scripts to check compliance.

> **Caveat:** Quarto's `poster-typst` extension and `_brand.yml` theming are both still under active development. Several items in [Notes / gotchas](scripts-and-ci.qmd#notes-gotchas) describe current rough edges (local patches, path handling, caching) that a future Quarto/Typst release may resolve outright. If something documented here seems to have changed, check the current Quarto release notes before assuming the workaround is still needed. 

There are three templates; each a single `.qmd` file that renders to **two** outputs from the same content in one pass: a large-format print PDF via [Typst](https://typst.app), and a responsive HTML "web poster."

![Comparison of the three print posters, one per row](comparison.png)

## Quickstart

1. Fork or clone this repo.
2. Copy one of the `templates/*/` folders (e.g. `cp -r templates/01-classic-academic templates/my-poster`) and edit its `poster.qmd`.
3. `quarto render templates/my-poster/poster.qmd` -- check `poster.pdf` and `poster.html`.
4. `Rscript scripts/render-all.R` to render + check every template for known regressions before you call it done.

The full walkthrough (including re-theming for a different organization, choosing a print size for a specific conference, and what each script/CI check does) is on the [documentation site](https://au-datascience.github.io/poster_templates/). 

- Start on the [Home](https://au-datascience.github.io/poster_templates/) page.

## Requirements

**To render a poster itself:** [Quarto](https://quarto.org) (a version at or near the one pinned in [`.quarto-version`](.quarto-version)) and R. 

- Every template's R code chunks are part of the *shipped example content*, not the poster mechanism itself, so if you replace the demo analysis with your own R or Python code, only your own code's package requirements apply. As shipped, the three example posters use:
    - `tidyverse`, `palmerpenguins`, `patchwork` (all three templates)
    - `broom` (`01-classic-academic` only, for `broom::tidy()` model summaries)
    - `knitr` (all three, for `knitr::kable()` tables -- normally auto-loaded by Quarto's R engine, listed here for completeness)
- No Python packages are required unless you add your own Python chunks. 
- No system libraries beyond a working R + Quarto install are needed for the print or web render themselves.
- Fonts (`Source Sans 3`, `STIX Two Text`) are fetched from Google and cached by Quarto at render time (see [`AGENTS.md`](AGENTS.md)'s "Fonts" section), not installed as system fonts.

**To run the helper scripts in `scripts/`:** all four use `tidyverse` and `here`; 
- `make-previews.R` additionally needs `magick` (which needs the ImageMagick system library).  
- `check-column-balance.R` needs `pdftools` (which needs the poppler system library). 
- `check-contrast.R` needs only `tidyverse`/`here`. It's pure source/CSS parsing, no rendering. 
- None of the scripts are required to render a poster; `quarto render templates/<name>/poster.qmd` alone is enough. 
    - They exist to catch regressions (see [Scripts & CI](https://au-datascience.github.io/poster_templates/scripts-and-ci.html)).
    - CI (`.github/workflows/posters.yml`) installs all of the above automatically via `r-lib/actions/setup-r-dependencies`, so you never need to install anything by hand just to see CI pass on a fork.

**Is this an `renv` repo?** No. For a small, stable package list on a repo meant to be forked and heavily edited by people building their own poster content (adding whatever packages *their* analysis needs), that friction outweighs the benefit. If you want tighter reproducibility for your own fork, e.g., pinning exact versions for a team where everyone must get identical output, `renv::init()` after cloning is a reasonable thing; it just isn't part of this template.

## Site map

| Page | Covers |
|---|---|
| [Home](https://au-datascience.github.io/poster_templates/) | Repo structure, forking and building your own poster |
| [Templates](https://au-datascience.github.io/poster_templates/templates.html) | The three template designs, and choosing a print size |
| [Content Guide](https://au-datascience.github.io/poster_templates/content-guide.html) | The Ethics & Broader Impact panel, shared resources (`_brand.yml`, `references.bib`, logo) |
| [Theming & Brand](https://au-datascience.github.io/poster_templates/theming.html) | Re-coloring the templates and WCAG contrast auditing; how `_brand.yml` fits in |
| [Scripts & CI](https://au-datascience.github.io/poster_templates/scripts-and-ci.html) | The R build/check scripts, the `Makefile`, continuous integration, and Notes / gotchas |
| [Why Typst?](https://au-datascience.github.io/poster_templates/why-typst.html) | Why print renders through Typst instead of LaTeX, and the trade-offs |
| [References](https://au-datascience.github.io/poster_templates/references.html) | Citations for sources referenced on the web site |

This site's source is [`docs-src/`](docs-src/) (a nested Quarto website project); it renders to `docs/`, which GitHub Pages serves directly.

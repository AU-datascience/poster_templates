# AGENTS.md

Project context and instructions for AI agents (and humans) working in this
repo. End-user-facing documentation lives in `docs-src/` (rendered to
`docs/`, published via GitHub Pages) — this file is for orientation and for
tracking open technical debt, not a substitute for it.

## What this is

A Quarto + Typst project: one `poster.qmd` source per template under
`templates/<name>/`, each rendering to both a print PDF (`poster-typst`
format, via a vendored Typst extension) and an HTML web version from the
same source. Three templates ship: `01-classic-academic`, `02-modern-cards`,
`03-minimal-story`.

## Orientation

- `scripts/templates.R` — the shared registry of templates (column counts,
  print sizes, column-fill baselines) the other scripts read. Adding a
  template to the multi-template layout is a one-line edit here.
- `scripts/render-all.R` — renders every discovered template to both formats
  and runs all output checks (pages, divider, acknowledgments, ethics panel,
  column balance, heading order, contrast). `--no-render` skips the render
  and checks existing output.
- `scripts/check-contrast.R`, `scripts/check-column-balance.R`,
  `scripts/make-previews.R` — standalone versions of checks/utilities
  `render-all.R` delegates to.
- `_extensions/quarto-ext/poster/` — vendored Typst poster extension with
  several **local patches that must be reapplied if the extension is
  reinstalled or updated** (see below).
- `docs-src/` — a separate, nested Quarto *website* project (its own
  `_quarto.yml`) documenting this one; renders to `docs/`, which GitHub
  Pages serves directly (Settings → Pages: branch `main`, `/docs`). After
  editing anything under `docs-src/`, run `quarto render docs-src` and
  commit the result — nothing else re-renders it, and `docs.yml` in CI
  will fail the build if you forget.
- `.quarto-version` — the Quarto version pinned in both CI workflows (see
  "CI" below).

## Common commands

```bash
make render               # clear the Typst package cache, then render + check everything
make check                 # run checks against existing output, no re-render
make check-quarto-version  # confirm local `quarto --version` matches the pinned .quarto-version
Rscript scripts/render-all.R --no-render
quarto render docs-src      # after any docs-src/ edit; commit the result
```

## CI

Two workflows, both live and running against
`AU-datascience/poster_templates` on GitHub (`gh run list` to check status):

- `.github/workflows/posters.yml` — a `contrast` job (pure source parsing,
  fast, unambiguous) and a `render` job (full Quarto/Typst render + every
  output check), on push, pull request, and manual dispatch.
- `.github/workflows/docs.yml` — renders `docs-src/` fresh and diffs the
  result against the committed `docs/`, to catch a docs edit that wasn't
  re-rendered. Not a deploy step; GitHub Pages serves the committed `/docs`
  directly, so there is nothing for CI to publish.

Quarto is pinned (not tracking `release`) via a single `.quarto-version`
file both workflows read, because an unpinned run once picked up a
pandoc/Typst-writer change that broke the institution-logo path
substitution. That specific bug is now also patched at the source (patch 5
below), but the pin stays — it protects against *any* such change, not just
the one that happened to be found. See `docs-src/scripts-and-ci.qmd`'s
"Updating the pinned Quarto version" section for the bump procedure.

The `render` job no longer installs any system fonts: `_brand.yml` declares
`STIX Two Text` and `Source Sans 3` as brand font resources (`source:
google`), so Quarto fetches and caches both under `.quarto/typst/fonts/` at
Typst-render time regardless of what's installed on the runner. See "Fonts"
below for how this was verified.

## Vendored extension patches (`_extensions/quarto-ext/poster`)

Reapply all of these if the extension is reinstalled or updated:

1. `poster.typ` accepts the institution logo as pre-loaded Typst `content`
   (loaded once in `typst-show.typ`) rather than a bare path string — Typst
   packages can't read files outside their own package directory.
2. `poster.typ` / `typst-show.typ` add a `footer-text-color` option
   (default white) for legibility against dark `footer-color` values.
3. `biblio.typ` (a new partial, registered in `_extension.yml`) sets
   `title: none` on the generated `#bibliography(...)` call, so Typst's own
   default heading doesn't duplicate each template's `#### References`.
4. `poster.typ` scales footer font sizes down (never up) on posters
   narrower than the extension's documented 36in default.
5. `typst-show.typ` strips a stray leading backslash from the substituted
   institution-logo path before calling `image()` on it — defends against a
   pandoc/Typst-writer bug that inserted one and broke the render ("path
   must not contain a backslash"). No-op when the path is already clean.

Because Quarto caches the vendored local Typst package under each project's
`.quarto/typst/packages/local/typst-poster/`, edits to `poster.typ` only
take effect after that cached copy is refreshed — `make render` (or
`make clean-cache`) does this; a plain `quarto render` silently keeps using
the stale cached version.

## Known issues

### Fonts — print fixed, web still not delivered (and why is now better understood)

`_brand.yml` declares `Source Sans 3` and `STIX Two Text` as brand font
resources (`source: google`):

```yaml
typography:
  fonts:
    - family: "Source Sans 3"
      source: google
    - family: "STIX Two Text"
      source: google
  base:
    family: "Source Sans 3"
  headings:
    family: "Source Sans 3"
    weight: bold
```

(`Source Sans Pro`/`Source Serif Pro`, previously named here, are the
legacy Adobe names — Google Fonts distributes these families as `Source
Sans 3`/`Source Serif 4`.)

**Print (Typst) is fixed and verified.** `poster.typ` hardcodes `set
text(font: "STIX Two Text")` for the body, and Quarto injects a `Source
Sans 3` show rule for headings. With the resources declared above, Quarto
fetches both from Google and caches them under `.quarto/typst/fonts/` at
render time — confirmed by rendering all three templates and grepping for
`unknown font family`/`variable fonts are not currently supported`
(both warnings are gone) and by inspecting `.quarto/typst/fonts/` directly
after a clean-cache render. This also means the runner no longer needs any
system fonts for Typst (the `fonts-stix` apt step in `posters.yml` was
removed — see "CI" above). Column-fill baselines in `scripts/templates.R`
were re-measured and updated in the same commit (small drift: e.g.
`03-minimal-story` 77 → 78).

**Web (HTML) fonts are still not delivered — but the reason turned out to
be different from what was originally suspected.** The font-resource
declaration above does *not* produce any `@font-face` blocks or
`--bs-body-font-family` change in the rendered HTML. This was re-diagnosed
from scratch rather than assumed fixed: a minimal reproduction (a bare
`_quarto.yml` + `_brand.yml`, using the exact `Jura`/`source: google`
example from Quarto's own brand.yml docs, no custom theme or scss at all)
still produces zero `@font-face` blocks and zero fetched font files for
`format: html` in this Quarto build (1.9.38). So this is not a naming
mistake or a scss-stack conflict in this project — brand.yml typography
does not appear to propagate into `html` output at all in this Quarto
version/build. `scss/poster-common.scss`'s sans stack now names the
correct current family (`"Source Sans 3"` rather than the nonexistent
`"Source Sans Pro"`), and the serif stack no longer promises an undeclared
`"Source Serif Pro"`/`"Source Serif 4"` — but neither is actually
self-hosted, so both fall through to their system-font fallbacks
(Helvetica/Arial, Georgia) in practice, same as before.

If you pick this up next:

1. Re-run the minimal reproduction above against a newer Quarto release
   (bump `.quarto-version` per the procedure in
   `docs-src/scripts-and-ci.qmd`, re-verify locally first) to check whether
   this is a version-specific bug that's since been fixed upstream.
2. If it still reproduces on a current release, search/file a
   `quarto-dev/quarto-cli` issue — the two prerequisites for a good report
   (a truly minimal project, and confirmation it isn't specific to this
   project's theme/scss setup) are already done above.
3. `render-all.R` still discards render stdout/stderr; capturing the log
   and failing on `unknown font family` would catch a regression on the
   print side faster than a column-fill drift would.

### Resolved

The rest of what an earlier version of this file (`HANDOFF-fonts-and-ci.md`,
written before this project had a real git remote) raised as open questions
is settled:

- The CI workflow has run — repeatedly and successfully — against
  `AU-datascience/poster_templates`; it was not still hypothetical.
- `quarto_posters/` is in fact the repository root; no working-directory
  fix-up was needed.
- The institution-logo path bug the first real CI run surfaced is patched
  (extension patch 5 above), and the Quarto version pin that also guards
  against it now lives in one file (`.quarto-version`) read by both
  workflows instead of being duplicated.
- The print body/heading fonts (`STIX Two Text`/`Source Sans 3`) are now
  pinned by declaration rather than depending on whatever happens to be
  installed locally — see "Fonts" above.

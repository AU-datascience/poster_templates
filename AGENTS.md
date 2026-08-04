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

### Fonts — print and web both confirmed working (an earlier false negative on web, corrected)

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

**Web (HTML) fonts are, in fact, delivered — an earlier version of this
note claimed otherwise, and that claim was a measurement artifact, not a
real limitation.** The original check grepped the raw rendered HTML for
literal strings like `@font-face` and `fonts.googleapis.com`. With
`embed-resources: true` (what every `poster.qmd` sets), Quarto inlines its
generated CSS as `<link href="data:text/css,...">` with the content
percent-encoded, so `@font-face` appears as `%40font%2Dface` in the raw
file — a plain string search can never find it there, encoded or not, and
silently reports "not found" instead of erroring. Decoding those
`data:text/css,` URIs (see `rendered_css_text()` in `scripts/render-all.R`)
shows the actual delivered CSS contains:

- Four self-hosted `@font-face` blocks for `Source Sans 3` (regular/bold ×
  normal/italic), each with its font file inlined as a base64
  `src: url(data:font/ttf;...)` — confirming it was fetched from Google at
  render time, not silently left to fall back to a system font.
- `--bs-body-font-family: Source Sans 3` and a matching
  `--bs-font-sans-serif` value in the generated Bootstrap `:root` block.
- `h1..h6{font-family:Source Sans 3;...}` in the compiled Bootstrap
  heading rules.

So both the `base` and `headings` roles `_brand.yml` assigns to
`Source Sans 3` do reach the rendered web output, exactly as documented for
color. `STIX Two Text` is also fetched and embedded as four `@font-face`
blocks, but genuinely never applied to any element on the web side —
correctly so, since `_brand.yml`'s own comment explains it's declared only
so Typst can find it for the print body; nothing under `base`/`headings`
names it for `html`.

**This was re-confirmed, not just re-read, before correcting the record:**
`scripts/render-all.R`'s `check_fonts()` now decodes every template's
rendered `poster.html` this way and asserts both the `@font-face` block and
the `--bs-body-font-family` variable are present (all three templates
currently pass). Separately, the standalone minimal reproduction mentioned
in an earlier version of this note — a bare `_brand.yml` + one `.qmd`, no
project file, no custom theme or scss, using the exact `Jura`/
`source: google` example from Quarto's own [brand
guide](https://quarto.org/docs/authoring/brand.html) — was rebuilt from
scratch and re-run against the same standalone `quarto` on `PATH`
(`1.9.38`, matching `.quarto-version`) that renders this project. It shows
the identical pattern: a self-hosted `@font-face` for `Jura`,
`--bs-body-font-family: Jura`, and `font-family:Jura` on the compiled
heading rule. So this reproduces cleanly outside this project's own
theme/scss stack too — there is no brand.yml/Bootstrap web-font limitation
to chase here, at least not on this Quarto version.

What made the original check wrong, concretely, for anyone hitting a
similar false negative elsewhere: `embed-resources: true` is what triggers
the percent-encoded `data:text/css,` delivery; the same check against a
non-embedded render (a plain `<link rel="stylesheet" href="doc_files/...">`
pointing at a separate, unencoded `.css` file) would have found the literal
`@font-face` text just fine. The bug was in assuming one delivery
mechanism while testing against a project that uses the other, compounded
by there being no compiler warning either way to flag the mismatch.

If a *real* web-font gap turns up in the future, re-run
`Rscript scripts/render-all.R --no-render` first and read the "web fonts
(brand)" row's detail column — it reports the two conditions
(`@font-face embedded`, `--bs-body-font-family set`) separately, so a
genuine regression is distinguishable from another decoding miss.

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
- The web body/heading font (`Source Sans 3`) was also independently
  re-confirmed as delivered, once checked by decoding the rendered CSS
  instead of grepping the raw, percent-encoded HTML file — see "Fonts"
  above. The earlier "web fonts aren't delivered" note, and the more basic
  "almost no `--bs-*` variables anywhere" puzzle it raised, were both
  artifacts of that same measurement mistake, not real gaps.

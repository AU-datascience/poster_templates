# Handoff: review the fonts and the CI workflow

Written 2026-08-03 for whoever picks this up after the project moves to its own
repository. Everything here was measured on the machine of origin (macOS,
Quarto 1.9.38, Typst 0.14.2), so re-measure after the move — several findings
are environment-dependent by nature.

Current state: `Rscript scripts/render-all.R` reports **25 passed, 0 failed**,
and all 22 audited color pairs reach WCAG AAA. Nothing below is a broken
build; these are two unresolved questions that the passing checks do *not*
cover.

---

## 1. Fonts

### The short version

Three font families are requested across the two output formats. Only one of
them demonstrably resolves, and **no check currently notices**.

| Requested | Where it comes from | Used for | Status on the origin machine |
|---|---|---|---|
| `STIX Two Text` | `_extensions/.../typst-poster/0.1.1/poster.typ` line 83 | print body text, all templates | **Resolves** |
| `Source Sans Pro` | `_brand.yml` → `typography.headings.family` | print headings (injected as a Typst `#show heading` rule), and the web sans stack | **Missing — silently falling back** |
| `Source Serif Pro` | `scss/poster-common.scss` `$font-family-serif` | web serif stack (01's headings) | **Not delivered** (see web section) |

### How to reproduce the findings

Typst warns rather than fails, and the warning is *invisible in our tooling*
because `render-all.R` renders with `stdout = FALSE, stderr = FALSE`. Render a
template by hand to see it:

```bash
cd templates/03-minimal-story
quarto render poster.qmd --to poster-typst 2>&1 | grep -i "unknown font"
# warning: unknown font family: source sans pro
```

Confirmed present in **all three** templates (1 warning each).

To test a specific face without rendering a poster:

```bash
printf '#set text(font: "STIX Two Text")\nHello\n' > /tmp/f.typ
quarto typst compile /tmp/f.typ    # silent => resolved; "unknown font" => missing
quarto typst fonts | grep -i stix  # what Typst can actually see
```

### Why `STIX Two Text` resolving here is not reassuring

macOS ships **STIXGeneral**, not STIX Two Text — check
`/System/Library/Fonts/Supplemental/`, which contains `STIXGeneral*.otf` only.
Yet `quarto typst fonts` lists 15 STIX entries and the face resolves, so it is
arriving from something else installed on this machine (a TeX distribution, a
user font install, or an application bundle). **Find out what**, because that
determines whether it survives the move:

```bash
quarto typst fonts | grep -i stix        # 15 entries here
fc-list 2>/dev/null | grep -i "stix two" # if fontconfig is available
ls ~/Library/Fonts /Library/Fonts | grep -i stix
```

If it turns out to be incidental, the print body font is effectively undefined
on a clean machine, and every poster's typography depends on a Typst fallback.

### Root cause, and a tested fix

The defect is a missing font *resource*, not a wrong font name. `_brand.yml`
names `Source Sans Pro` under `typography.base` and `typography.headings` but
never declares a `typography.fonts:` entry. Per the brand.yml docs a `family`
"should match a font resource declared in `typography.fonts`" — with no
resource declared, Quarto treats the name as a system font, so Typst falls back
and the HTML gets no webfont. brand.yml applies to **both** `html` and `typst`,
so one declaration fixes both formats.

Also note the family names are wrong: on Google Fonts these faces are
**`Source Sans 3`** and **`Source Serif 4`**. `Source Sans Pro`/`Source Serif
Pro` are the legacy Adobe names. Both `Source Sans 3` and, usefully,
**`STIX Two Text`** are available from Google Fonts (verified against the
`css2` endpoint).

This was tested by patching `_brand.yml` to:

```yaml
typography:
  fonts:
    - family: "Source Sans 3"
      source: google
  base:
    family: "Source Sans 3"
  headings:
    family: "Source Sans 3"
    weight: bold
```

Measured results, rendering `03-minimal-story`:

| | Before | After |
|---|---|---|
| Typst `unknown font family` warnings | 1 per template | **0** |
| `@font-face` blocks in the HTML | 2 | **23** |
| References to `fonts.gstatic` / `fonts.googleapis` in the HTML | 0 | **0** — the font is *inlined*, not hotlinked |
| `--bs-body-font-family` | fallback stack | `Source Sans 3` |
| Column fill for 03 | 79 | 80 |

Two things that makes this the preferred route:

- **It fixes print and web from one declaration**, which vendoring by hand does
  not (that needs `font-paths` per template *and* SCSS delivery separately).
- **It self-hosts rather than hotlinks.** Because `embed-resources: true` is set,
  the font is embedded in the HTML with no runtime call to Google. That matters
  here beyond convenience: hotlinking Google's CDN transmits every visitor's IP
  address to Google, which sits badly with the templates' own privacy/GDPR
  disclosure panel. Watch the HTML file size, though — 23 inlined faces are not
  free.

### Remaining decisions

1. **Investigate the new Typst warning.** After the change the only warning is
   `variable fonts are not currently supported and may render incorrectly`.
   It was *absent* before the change, so it comes from the downloaded
   `Source Sans 3` (a variable font), not from `STIX Two Text`. Look at a
   rendered PDF and decide whether to accept it or pin static instances.
2. **Consider sourcing `STIX Two Text` the same way.** It is on Google Fonts, so
   declaring it as a brand font resource should place the file where Typst can
   find it, making the print body font reproducible on a clean machine and in
   CI *without* patching the vendored package (which still asks for it by name
   at `poster.typ` line 83). This is the single change that would most improve
   reproducibility. Verify that the package's `set text(font: ...)` does resolve
   against the brand-supplied file.
3. **Re-measure the balance baselines afterwards.** Drift was small in the test
   (79 → 80 for 03) because Typst's *body* font is pinned to `STIX Two Text` by
   the package, so only headings changed. Pinning the body font too will move
   the numbers more.
4. **Align the SCSS stacks** with whatever families end up declared, so the
   source stops naming `Source Sans Pro`/`Source Serif Pro`.

The experiment was reverted; `_brand.yml` is back to its original state and the
suite is green.

### Web fonts are declared but not delivered

`poster-common.scss` sets `$font-family-sans-serif: "Source Sans Pro",
Helvetica, Arial, sans-serif` and a matching serif stack, but the rendered HTML
contains no Google Fonts link and no matching `@font-face`:

```bash
grep -c 'fonts.googleapis.com' templates/02-modern-cards/poster.html   # 0
grep -c 'Source Sans'          templates/02-modern-cards/poster.html   # 0
```

So the web posters fall back to Helvetica/Arial and Georgia. That is a
perfectly reasonable result, but it is not what the files say is intended.
Either add webfont delivery (a `@import` in the SCSS, or self-hosted woff2 for
`embed-resources: true` to inline) or simplify the stacks to system fonts so
the source stops promising something it does not deliver.

### Knock-on effect on the checks

`scripts/templates.R` holds pixel-measured column-fill baselines
(`100/100/82`, `44/82`, `79`) produced with whatever faces resolved here. A
different font changes line breaking, which changes how far down a column the
content reaches. So:

- Do **not** treat a balance failure on a new machine as a content regression
  until you have confirmed the fonts match.
- Once fonts are pinned, re-measure and update the baselines in one commit,
  noting the font state in the message.

### Suggested addition

`render-all.R` currently hides render output entirely, which is precisely why
the `Source Sans Pro` warning went unnoticed for so long. Consider capturing
the render log and adding a check that fails on `unknown font family` — it is a
two-line change to `render_template()` (capture `stdout`/`stderr` instead of
discarding them) and it would have caught this immediately.

---

## 2. The CI workflow

File: `.github/workflows/posters.yml`.

### It has never run

There was no git repository anywhere in the tree when it was written
(`git rev-parse --show-toplevel` failed). The YAML parses and the step list is
sane, but nothing has executed it. Treat the first push as the real test.

### Check the placement assumption first

The file assumes **`quarto_posters/` is the repository root**, which is what the
README's "Code & data" link implies. If you commit a parent folder instead:

1. Move the file to `<repo-root>/.github/workflows/posters.yml`.
2. Add a working directory so the scripts find `_quarto.yml`:
   ```yaml
   defaults:
     run:
       working-directory: quarto_posters
   ```
3. Fix the artifact paths in the final step, which are currently
   `templates/*/poster.pdf` and `templates/*/poster.html`.

All three scripts call `stop_unless_project_root()`, so a wrong working
directory fails fast with a clear message rather than doing something strange.

### The two jobs, and why they are split

| Job | Command | Dependencies |
|---|---|---|
| `contrast` | `Rscript scripts/check-contrast.R --require-aaa` | R + tidyverse only |
| `render` | `Rscript scripts/render-all.R` | Quarto, Typst, fonts, pdftools (poppler), magick (ImageMagick) |

The split is deliberate: the contrast audit is pure source parsing, so it is
fast and cannot be perturbed by a toolchain or font problem. Keep it that way.
Every pair currently reaches AAA, so `--require-aaa` is a real gate; if a color
change legitimately lands at AA, drop the flag rather than deleting the job.

### The font step is probably wrong

```yaml
- run: sudo apt-get install -y fonts-stix
```

Given the finding above — that macOS ships STIXGeneral while the templates want
**STIX Two Text** — `fonts-stix` on Ubuntu is likely the same generation and
therefore the wrong face. Verify on the first run with:

```bash
quarto typst fonts | grep -i "stix"
```

**Better: delete this step entirely.** If the fonts are declared as brand font
resources with `source: google` (see the fonts section above), Quarto fetches
them into the project at render time and the runner needs no system fonts at
all. That removes the most fragile part of this job and makes CI and local
renders agree by construction. Until then, expect the column-balance check to
be what fails when the font is wrong.

### First-push checklist

1. Does the `contrast` job pass? It should, and it is font-independent — if it
   fails, something structural broke in the move (paths, missing files).
2. Does `render` get through `quarto render` at all?
3. Grep the render log for `unknown font family`.
4. Compare the reported column-fill numbers against the baselines in
   `scripts/templates.R`. Divergence here is the font, not the content.
5. Download the `rendered-posters` artifact and look at a PDF before trusting
   any of the numbers.

---

## 3. Orientation for a new session

Run from the project root (the folder with `_quarto.yml`):

```bash
Rscript scripts/render-all.R              # render everything + all checks
Rscript scripts/render-all.R --no-render  # checks against existing output
Rscript scripts/check-contrast.R --require-aaa
Rscript scripts/make-previews.R           # refresh README images after a content change
```

Scripts and what they own:

- `scripts/templates.R` — shared registry: template dirs, column counts, print
  sizes, column-fill baselines. Adding a template is a one-line edit here.
- `scripts/check-column-balance.R` — column-fill measurement (function + CLI).
- `scripts/check-contrast.R` — WCAG audit; parses the palette, the stylesheets'
  own `color:`/`background:`/`font-size` declarations (including both
  `linear-gradient()` stops), and each template's footer YAML.
- `scripts/render-all.R` — renders all templates, runs six output checks each,
  then delegates the contrast audit.

The README's "Notes / gotchas", "Build & check scripts", and "Re-coloring the
templates" sections carry the rest of the context, including several
Typst-specific traps that are easy to re-introduce (raw HTML inside a
`.content-visible` div silently truncating the Typst output; `####` headings
arriving as Typst *level 3*; heading sizes needing to stay below the title).

.PHONY: render check clean-cache

# Quarto's typst compiler resolves `@local/typst-poster:0.1.1` from
# .quarto/typst/packages, which Quarto copies there from
# _extensions/quarto-ext/poster/typst/packages the first time it's needed.
# That copy is never refreshed on later renders, so editing
# _extensions/.../poster.typ silently has no effect until the cache is
# cleared (see .quarto/typst/packages/local/typst-poster/0.1.1/poster.typ
# going stale, discovered while fixing the footer-overflow bug). Every
# render target below clears it first so this can't happen again.
clean-cache:
	rm -rf .quarto/typst/packages

# Renders every poster template (both poster-typst and html) and runs the
# regression checks in scripts/render-all.R.
render: clean-cache
	Rscript scripts/render-all.R

# Runs the regression checks against whatever output already exists,
# without re-rendering (and without touching the typst package cache,
# since nothing is being compiled).
check:
	Rscript scripts/render-all.R --no-render

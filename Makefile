.PHONY: render check clean-cache check-quarto-version

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

# CI pins Quarto to the version in .quarto-version (read by both
# .github/workflows/posters.yml and docs.yml) rather than tracking `release`,
# because an unpinned run once picked up a pandoc/Typst-writer change that
# broke the institution-logo path substitution -- not reproducible locally,
# since a pin only ever silently drifts in CI. Run this after installing a
# candidate new Quarto locally and *before* bumping .quarto-version, so the
# bump is a deliberate, re-verified choice rather than CI finding out first.
check-quarto-version:
	@pinned=$$(cat .quarto-version); \
	actual=$$(quarto --version); \
	if [ "$$pinned" != "$$actual" ]; then \
		echo "Local Quarto ($$actual) != .quarto-version ($$pinned)." >&2; \
		echo "Install $$pinned to test against the pin, or update" >&2; \
		echo ".quarto-version to $$actual after re-rendering and checking" >&2; \
		echo "output locally (make render)." >&2; \
		exit 1; \
	fi; \
	echo "Local Quarto ($$actual) matches the pinned .quarto-version."

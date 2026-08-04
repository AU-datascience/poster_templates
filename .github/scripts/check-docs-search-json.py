#!/usr/bin/env python3
"""Fail if docs/search.json's *content* differs from the committed version.

Used by .github/workflows/docs.yml, which renders docs-src/ fresh
(overwriting docs/search.json in place) and then invokes this script to
compare that fresh output against the version already committed at HEAD.

Not a raw text diff: entry order in search.json is not stable across
platforms (observed: entries reordered between a macOS and a Linux render
of identical source, with zero real content change), so both versions are
sorted by objectID before comparing. See the workflow file for the fuller
story, including why the same is true -- for a different reason -- of the
rest of docs/ (a Sass-compiler content-hash difference in the bundled
Bootstrap CSS), which is why this script only looks at search.json rather
than the whole directory.
"""

import difflib
import json
import subprocess
import sys


def normalize(text: str) -> str:
    records = json.loads(text)
    records.sort(key=lambda r: r.get("objectID", ""))
    return json.dumps(records, indent=2, sort_keys=True)


def main() -> int:
    committed = subprocess.run(
        ["git", "show", "HEAD:docs/search.json"],
        capture_output=True, text=True, check=True,
    ).stdout
    with open("docs/search.json", encoding="utf-8") as f:
        fresh = f.read()

    a, b = normalize(committed), normalize(fresh)
    if a == b:
        print("docs/search.json content matches (order-independent).")
        return 0

    print(
        "::error::docs/ is stale relative to docs-src/. "
        "Run `quarto render docs-src` locally and commit the result."
    )
    diff = difflib.unified_diff(a.splitlines(), b.splitlines(), lineterm="")
    print("\n".join(list(diff)[:200]))
    return 1


if __name__ == "__main__":
    sys.exit(main())

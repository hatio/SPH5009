#!/usr/bin/env bash
#
# Quarto post-render hook. Fixes the footer logo paths on pages that render
# into subdirectories.
#
# The page-footer in _quarto.yml is raw HTML with <img src="assets/logos/...">,
# and Quarto emits it verbatim on every page. That relative path resolves on
# index.html at the site root but not on chapters/... or appendices/..., so
# the three logos 404 on every page except the front page. A root-absolute
# path is not an option either: the site is served under a project prefix
# (/r-intro/) on GitHub Pages and under / in a local preview, so no single
# absolute path is right in both places. Per-page relative paths are the only
# form that works everywhere, and this hook writes them: pages one level down
# get src="../assets/logos/...".

set -euo pipefail

cd "$(dirname "$0")/.."

out="${QUARTO_PROJECT_OUTPUT_DIR:-_book}"
[ -d "$out" ] || { echo "fix-footer-paths: no output directory at $out" >&2; exit 1; }

find "$out/chapters" "$out/appendices" -name '*.html' -exec \
  sed -i '' 's|src="assets/logos/|src="../assets/logos/|g' {} +

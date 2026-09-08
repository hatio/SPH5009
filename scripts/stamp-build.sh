#!/usr/bin/env bash
#
# Quarto post-render hook. Writes build-info.json into the rendered site so the
# published copy carries the commit that produced it.
#
# Without this there is no way to ask "is what is live still what main says?"
# The gh-pages branch holds only rendered HTML, and HTML does not know which
# revision of the source it came from.

set -euo pipefail

out="${QUARTO_PROJECT_OUTPUT_DIR:-_book}"
[ -d "$out" ] || { echo "stamp-build: no output directory at $out" >&2; exit 1; }

commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

# A stamp taken from a dirty tree names a commit that does not contain what was
# actually rendered. Record that rather than quietly implying otherwise.
#
# "Dirty" has to mean the SOURCES were uncommitted, not that anything at all
# changed. This hook runs after the render, and the render itself writes to
# tracked files: _freeze/ picks up new chunk output, and Quarto maintains its
# own entries in .gitignore. Counting those would mark every single build
# dirty, which would make the flag useless and the sync check cry wolf.
if [ -z "$(git status --porcelain -- . \
            ':(exclude)_freeze' ':(exclude).gitignore' ':(exclude)_book' 2>/dev/null)" ]; then
  dirty=false
else
  dirty=true
fi

cat > "$out/build-info.json" <<JSON
{
  "commit": "$commit",
  "dirty": $dirty,
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "quarto": "$(quarto --version 2>/dev/null || echo unknown)"
}
JSON

#!/usr/bin/env bash
#
# Render the book and publish it to the gh-pages branch.
#
#   ./scripts/publish.sh
#
# main holds the source. gh-pages holds the rendered site and nothing else.
# GitHub serves gh-pages. Nothing rendered is committed to main, so a chapter
# edit is a one-file diff rather than a one-file diff buried in ninety
# regenerated HTML pages.
#
# The cost of that split is that main can look perfectly up to date while the
# live site is stale, because publishing is a separate act from pushing. That
# is what build-info.json and scripts/check-pages-sync.sh exist to catch.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
EXPECTED_PAGES=19
OUT="_book"

fail() { printf '\n  FAILED: %s\n\n' "$1" >&2; exit 1; }

# A preview watching the files will race the render and can leave the output
# half-moved. This has actually happened.
if pgrep -f "quarto preview" > /dev/null 2>&1; then
  fail "a 'quarto preview' is running. Stop it first — it will race this render."
fi

# The published site records the commit it came from. If the tree is dirty that
# record is a lie, and the sync check downstream becomes worthless.
if ! git diff --quiet HEAD 2>/dev/null; then
  git status --short >&2
  fail "uncommitted changes. Commit them first so the published site records a real commit."
fi

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || fail "on branch '$branch'. Publish from main."

# Quarto will not create the branch for you when running non-interactively:
# with --no-prompt it stops with "the remote origin does not have a branch
# named gh-pages" and tells you to run it interactively once. Do that job here
# instead, so a fresh clone can publish without a manual first step.
if ! git ls-remote --exit-code --heads origin gh-pages > /dev/null 2>&1; then
  echo "==> origin has no gh-pages branch; creating an empty one"
  tmp=$(mktemp -d)
  git worktree add --detach "$tmp" > /dev/null 2>&1 || fail "could not create a temporary worktree"
  (
    set -euo pipefail
    cd "$tmp"
    git checkout --orphan gh-pages > /dev/null 2>&1
    git rm -rf . > /dev/null 2>&1 || true
    : > .nojekyll
    git add .nojekyll
    git commit -q -m "Initialise gh-pages

Empty starting point. quarto publish gh-pages replaces the contents of this
branch on every publish; nothing here is edited by hand."
    git push -q -u origin gh-pages
  ) || { git worktree remove --force "$tmp" 2>/dev/null; fail "could not initialise the gh-pages branch"; }
  git worktree remove --force "$tmp" 2>/dev/null || true
  echo "    created and pushed."
fi

# freeze: auto decides whether to re-run a chapter's R by hashing that chapter's
# .qmd. Nothing else. Change _common.R, the ggplot theme, or the dataset itself
# and every chunk stays frozen: the render succeeds, reports nothing unusual,
# and publishes the OLD numbers. Verified by changing the severity cutoff in
# _common.R from 100 to 150 and re-rendering — the page still said 215/53/77
# and not one chunk executed.
#
# So the freeze has to be invalidated on anything the analysis actually depends
# on. renv.lock is in the list because a package upgrade can change output just
# as surely as an edit can.
FINGERPRINT_FILE="_freeze/.analysis-fingerprint"
fingerprint=$(
  {
    find _common.R R data -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s ' "$f"; shasum -a 256 "$f" | awk '{print $1}'
    done
    shasum -a 256 renv.lock 2>/dev/null | awk '{print "renv.lock " $1}'
  } | shasum -a 256 | awk '{print $1}'
)

if [ -f "$FINGERPRINT_FILE" ] && [ "$(cat "$FINGERPRINT_FILE")" = "$fingerprint" ]; then
  echo "==> analysis inputs unchanged; the chunk cache stands"
else
  if [ -d _freeze ]; then
    echo "==> analysis inputs changed (_common.R, R/, data/ or renv.lock)"
    echo "    clearing the chunk cache so every chapter re-runs against them"
    rm -rf _freeze
  fi
fi

# Render and publish are deliberately separate steps, with the checks between
# them. `quarto publish` renders by default, which would put every check after
# the deploy — a failing check would then be a report on a site that is already
# live, which is not a gate.
echo "==> rendering"
quarto render || fail "quarto render exited non-zero. Read the output above."

mkdir -p _freeze && printf '%s\n' "$fingerprint" > "$FINGERPRINT_FILE"

echo "==> checking the render before anything is published"

# Pages render into _book/chapters/ and _book/appendices/, with index.html at
# the top level. The redirect stubs that scripts/make-redirects.sh writes at
# the old flat URLs are also .html files inside _book, so count only the real
# pages: the index plus whatever is in the two directories.
pages=$(( 1 + $(find "$ROOT/$OUT/chapters" "$ROOT/$OUT/appendices" -name '*.html' | wc -l | tr -d ' ') ))
[ "$pages" = "$EXPECTED_PAGES" ] || fail "$OUT/ has $pages pages, expected $EXPECTED_PAGES. Update EXPECTED_PAGES if you added a chapter."

# A failed render can strand a page next to its source, which is now anywhere
# in the tree — search everywhere except the output directory and the trees
# that legitimately contain HTML (the renv library ships package docs).
stray=$(find "$ROOT" -path "$ROOT/$OUT" -prune -o -path "$ROOT/renv" -prune -o -path "$ROOT/.git" -prune -o -path "$ROOT/.quarto" -prune -o -name '*.html' -print | wc -l | tr -d ' ')
[ "$stray" = "0" ] || fail "$stray rendered page(s) stranded outside $OUT/."

[ -f "$ROOT/$OUT/search.json" ] || fail "$OUT/search.json is missing. Search will silently return nothing."
[ -f "$ROOT/$OUT/build-info.json" ] || fail "$OUT/build-info.json is missing. The post-render stamp did not run."

# The footer logos live at the site root, so a page in a subdirectory must
# reference them as ../assets/logos/. The raw footer HTML says assets/logos/
# verbatim, and if fix-footer-paths.sh did not run, the logos 404 on every
# page except the index — silently, because the render itself succeeds.
# The || true matters: grep exits 1 when it finds nothing, which is the
# success case here, and pipefail would otherwise turn it into a script exit.
badlogo=$( { grep -l 'src="assets/logos/' "$ROOT/$OUT/chapters"/*.html "$ROOT/$OUT/appendices"/*.html 2>/dev/null || true; } | wc -l | tr -d ' ')
[ "$badlogo" = "0" ] || fail "$badlogo page(s) in subdirectories reference assets/logos/ relatively. The footer logos would 404 — did the fix-footer-paths post-render hook run?"

echo "==> checking every solution link resolves"
# Match href attributes only. Scanning raw text also picks up prose that
# mentions the link pattern — build.qmd discusses "solutions.html#sec-sol-…"
# in a <code> span, which looks like a link with an empty slug and fails a
# naive check for reasons that have nothing to do with the book.
find "$ROOT/$OUT" -name '*.html' -print0 | xargs -0 grep -hoE 'href="[^"]*solutions\.html#sec-sol-[a-z0-9-]+"' \
  | sed 's/.*#//; s/"$//' | sort -u > /tmp/rintro-links.$$
while IFS= read -r slug; do
  grep -q "id=\"$slug\"" "$ROOT/$OUT/appendices/solutions.html" || fail "dead solution link: $slug has no anchor in appendices/solutions.html"
done < /tmp/rintro-links.$$
links=$(wc -l < /tmp/rintro-links.$$ | tr -d ' '); rm -f /tmp/rintro-links.$$

echo "==> checking every back-link resolves"
grep -hoE 'href="[^"]*[a-z-]+\.html#exr-[a-z0-9-]+"' "$ROOT/$OUT/appendices/solutions.html" \
  | sed 's/href="//; s/"$//' | sort -u > /tmp/rintro-back.$$
while IFS= read -r target; do
  page="${target%%#*}"; anchor="${target##*#}"
  # hrefs are relative to the appendix page, e.g. ../chapters/transform.html.
  # Resolve against appendices/ and normalise the .. away instead of
  # stripping directories — chapters/transform.html, not transform.html.
  page=$(printf 'appendices/%s\n' "$page" | sed 's#[^/]*/\.\./##')
  [ -f "$ROOT/$OUT/$page" ] || fail "back-link points at $page, which was not rendered"
  grep -q "id=\"$anchor\"" "$ROOT/$OUT/$page" || fail "dead back-link: $anchor is not in $page"
done < /tmp/rintro-back.$$
backlinks=$(wc -l < /tmp/rintro-back.$$ | tr -d ' '); rm -f /tmp/rintro-back.$$

echo "==> publishing to gh-pages"
quarto publish gh-pages --no-render --no-prompt --no-browser \
  || fail "quarto publish exited non-zero. Read the output above."

echo "==> confirming gh-pages now matches main"
"$ROOT/scripts/check-pages-sync.sh" --local || fail "published site does not match main. See above."

cat <<SUMMARY

  Published. $pages pages, $(find "$ROOT/$OUT" -name '*.svg' | wc -l | tr -d ' ') figures,
  $links solution links and $backlinks back-links all resolving.

  https://cerm-nus.github.io/r-intro/

SUMMARY

# Rendering rewrites _freeze/, which is tracked. Leaving it uncommitted means
# the next publish refuses to start on a dirty tree, and a fresh clone would
# re-execute every chunk instead of reusing the cache.
if [ -n "$(git status --porcelain -- _freeze .gitignore)" ]; then
  cat <<'NEXT'
  The render updated the chunk cache. Commit it so the next publish can start
  from a clean tree:

    git add _freeze .gitignore && git commit -m "Update chunk cache"

NEXT
fi

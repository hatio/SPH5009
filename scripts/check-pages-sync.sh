#!/usr/bin/env bash
#
# Is the published site still what main says it should be?
#
#   ./scripts/check-pages-sync.sh          # check against the remote
#   ./scripts/check-pages-sync.sh --local  # skip the fetch, use what is already here
#
# Exit 0 in sync, 1 if the site is stale, 2 if it could not tell.
#
# This exists because splitting source (main) from output (gh-pages) makes
# staleness invisible. With the site committed to main, forgetting to rebuild
# showed up as a dirty working tree. Here main is clean whether or not you ever
# published, so nothing tells you the site is out of date. This does.
#
# It works by reading build-info.json off gh-pages, which scripts/stamp-build.sh
# wrote into the site at render time, and comparing the commit recorded there
# against the tip of main.

set -uo pipefail

cd "$(dirname "$0")/.."

LOCAL=false
[ "${1:-}" = "--local" ] && LOCAL=true

# Anything that changes what the rendered site looks like. A README-only commit
# leaves the site correct, and reporting that as stale would train you to
# ignore this script.
SITE_SOURCES=(
  '*.qmd' '_quarto.yml' '_common.R' 'R/' 'scss/' 'data/' 'assets/' 'scripts/stamp-build.sh'
)

if [ "$LOCAL" = false ]; then
  echo "==> fetching"
  git fetch --quiet origin main gh-pages 2>/dev/null || {
    echo "  could not fetch. Is there a gh-pages branch yet? Run ./scripts/publish.sh" >&2
    exit 2
  }
  MAIN_REF=origin/main
  PAGES_REF=origin/gh-pages
else
  MAIN_REF=main
  PAGES_REF=gh-pages
fi

git rev-parse --verify --quiet "$PAGES_REF" > /dev/null || {
  echo "  no $PAGES_REF branch. The site has never been published. Run ./scripts/publish.sh" >&2
  exit 2
}

info=$(git show "$PAGES_REF:build-info.json" 2>/dev/null) || {
  echo "  $PAGES_REF has no build-info.json — it was published before this check existed." >&2
  echo "  Run ./scripts/publish.sh once to stamp it." >&2
  exit 2
}

published=$(printf '%s' "$info" | sed -n 's/.*"commit"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/p')
dirty=$(printf '%s' "$info"    | sed -n 's/.*"dirty"[[:space:]]*:[[:space:]]*\([a-z]*\).*/\1/p')
built=$(printf '%s' "$info"    | sed -n 's/.*"built_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
head_sha=$(git rev-parse "$MAIN_REF")

echo "  published from : ${published:-unknown}  ($built)"
echo "  main is at     : $head_sha"

[ -n "$published" ] || { echo "  could not read a commit out of build-info.json" >&2; exit 2; }

if [ "$dirty" = "true" ]; then
  echo
  echo "  STALE: the site was built from a dirty working tree, so the commit above" >&2
  echo "  does not describe what is actually live. Republish: ./scripts/publish.sh" >&2
  exit 1
fi

if [ "$published" = "$head_sha" ]; then
  echo
  echo "  In sync. The live site was built from the current tip of main."
  exit 0
fi

git cat-file -e "${published}^{commit}" 2>/dev/null || {
  echo >&2
  echo "  STALE: the site was built from commit $published, which is not in this" >&2
  echo "  repository — history was rewritten, or it was built elsewhere." >&2
  exit 1
}

behind=$(git rev-list --count "$published..$MAIN_REF" 2>/dev/null || echo "?")
changed=$(git diff --name-only "$published" "$MAIN_REF" -- "${SITE_SOURCES[@]}" 2>/dev/null)

echo
if [ -n "$changed" ]; then
  echo "  STALE: main is $behind commit(s) ahead and these affect the site:" >&2
  printf '    %s\n' $changed >&2
  echo >&2
  echo "  Republish: ./scripts/publish.sh" >&2
  exit 1
fi

echo "  Effectively in sync. main is $behind commit(s) ahead, but none of them"
echo "  touch anything the rendered site is built from."
exit 0

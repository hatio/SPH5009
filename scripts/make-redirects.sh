#!/usr/bin/env bash
#
# Quarto post-render hook. Writes redirect stubs at the book's old flat URLs.
#
# The chapters and appendices used to render to /setup.html, /solutions.html
# and so on; they now render to /chapters/... and /appendices/.... The old
# paths live on in lecture slides, LMS pages and bookmarks, and GitHub Pages
# has no server-side redirect mechanism, so each old path gets a static stub
# that forwards to the new location.
#
# The stubs are regenerated on every render rather than maintained by hand,
# and `quarto publish` carries them to gh-pages automatically. Remove a name
# from the lists only when you are sure nothing links to it any more.

set -euo pipefail

cd "$(dirname "$0")/.."

out="${QUARTO_PROJECT_OUTPUT_DIR:-_book}"
[ -d "$out" ] || { echo "make-redirects: no output directory at $out" >&2; exit 1; }

chapters="setup good-practice foundations rectangles import transform missing conditionals groups visualise functions iteration capstone next-steps"
appendices="solutions data build colophon"

stub() {
  # $1 = old flat page name, $2 = new path relative to the site root
  cat > "$out/$1.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>This page has moved</title>
<meta http-equiv="refresh" content="0; url=$2">
<link rel="canonical" href="$2">
</head>
<body>
<p>This page has moved to <a href="$2">$2</a>.</p>
</body>
</html>
HTML
}

for name in $chapters;   do stub "$name" "chapters/$name.html";   done
for name in $appendices; do stub "$name" "appendices/$name.html"; done

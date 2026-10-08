#!/usr/bin/env bash
# resid-book: the server, served over real HTTP.
#
# Usage: tests/run.sh [-c compiler] [-d depmap]
#
# The sample book under examples/sample is the fixture: a splash home with
# a hero, a normal page with a table of contents, and a page of code fences.
# The suite builds the server, serves the book and checks the routes, the
# sidebar, the table of contents, the highlighting, the live search, the
# assets and the 404.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="${RESIDC:-$ROOT/../resid/build/boot/stage2.bin}"
DEPMAP="$ROOT/deps.txt"
while getopts "c:d:" opt; do
    case "$opt" in
        c) COMPILER="$(realpath "$OPTARG")" ;;
        d) DEPMAP="$(realpath "$OPTARG")" ;;
        *) exit 2 ;;
    esac
done
[ -x "$COMPILER" ] || { echo "compiler not found: $COMPILER (run ./boot.sh in the resid checkout)"; exit 2; }
export RESID_HOME="${RESID_HOME:-$(cd "$(dirname "$COMPILER")" && pwd)}"
[ -f "$DEPMAP" ] || { echo "depmap not found: $DEPMAP (resid-manifest depmap resid.toml deps.txt)"; exit 2; }

cd "$ROOT"
T="$(mktemp -d)"
trap 'rm -rf "$T"; kill ${SRV:-0} 2>/dev/null' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
# check <name> <expected-substring> <cmd...>
check() {
    local name="$1" want="$2"; shift 2
    local out; out="$("$@" 2>&1)"
    if echo "$out" | grep -q -- "$want"; then ok; else bad "$name (want '$want' in: $(echo "$out" | head -2 | tr '\n' ' '))"; fi
}
# checkr <name> <expected-status> <path>
checkr() {
    local name="$1" want="$2" path="$3"
    local code; code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT$path")"
    if [ "$code" = "$want" ]; then ok; else bad "$name ($path: status $code, want $want)"; fi
}
# body <path>
body() { curl -s "http://127.0.0.1:$PORT$1"; }

# ── Build ──────────────────────────────────────────────────────────────
if ! "$COMPILER" src/site.resid -o "$T/resid-book" --profile debug -depmap "$DEPMAP" > "$T/build.log" 2>&1; then
    echo "resid-book did not compile:"; grep -m3 -B1 -A2 "error" "$T/build.log"; exit 1
fi
ok

# ── Serve ──────────────────────────────────────────────────────────────
"$T/resid-book" examples/sample/book.toml --port 0 --port-file "$T/port" > "$T/run.log" 2>&1 &
SRV=$!
for _ in $(seq 1 60); do [ -s "$T/port" ] && break; sleep 0.1; done
PORT="$(cat "$T/port" 2>/dev/null)"
[ -n "$PORT" ] || { echo "server did not report a port:"; cat "$T/run.log"; exit 1; }

# ── Routes ─────────────────────────────────────────────────────────────
checkr "home" 200 "/"
checkr "page" 200 "/intro/"
checkr "page without a trailing slash" 200 "/numbers"
checkr "asset (mascot)" 200 "/mascot.svg"
checkr "asset in a nested directory" 200 "/img/mark.svg"
# A path that climbs out of the asset directories is not an asset. These
# go out with --path-as-is, because curl would fold the dot segments away
# and the server would never see them.
checkraw() { # checkraw <name> <expected-status> <path>
    local name="$1" want="$2" path="$3"
    local code; code="$(curl -s --path-as-is -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT$path")"
    if [ "$code" = "$want" ]; then ok; else bad "$name ($path: status $code, want $want)"; fi
}
checkraw "traversal refused" 404 "/Resid/../book.toml"
checkraw "deep traversal refused" 404 "/Resid/../../etc/passwd"
checkraw "dot segment refused" 404 "/Resid/./mascot.svg"
checkr "theme script" 200 "/theme.js"
checkr "missing page" 404 "/nope"

# ── Home page: hero, cards, folded code ────────────────────────────────
check "hero tagline" "A book that is a directory" "$(body /)"
check "hero action" "Read the intro" "$(body /)"
# The hero image is written quoted in the frontmatter (`html: '<img />'`).
# Those quotes must not survive into the page: once they did, a `'` was
# printed on each side of the picture.
check "hero image" '<div class="hero"><img class="invert-dark" src="/mascot.svg"' "$(body /)"
if body / | grep -q "'<img"; then bad "frontmatter quotes leaked into the page"; else ok; fi
# Monochrome artwork is inverted on a dark page, from the toggle and from the
# OS preference alike. The file itself is never touched. (`check` matches with
# a basic regex, so no needle here may contain a bracket.)
check "dark inverts monochrome artwork" "invert-dark{filter:invert(1)}" "$(body /)"
check "os preference inverts too" "prefers-color-scheme:dark" "$(body /)"
check "light theme leaves artwork alone" "invert-dark{filter:none}" "$(body /)"
check "brand artwork inverts" 'class="brand" href="/"><img class="invert-dark"' "$(body /)"
check "cards rendered" "class=\"card\"" "$(body /)"
# The MDX `import ... from '@astrojs/starlight/components'` line must not
# reach the page: check the body does NOT contain it.
if body / | grep -q "astrojs/starlight"; then bad "astro import leaked into the page"; else ok; fi

# ── A normal page: sidebar, TOC, pager, edit ───────────────────────────
check "sidebar topic" "class=\"topic\"" "$(body /intro/)"
check "sidebar active link" "class=\"on\" href=\"/intro/\"" "$(body /intro/)"
check "table of contents" "On this page" "$(body /intro/)"
check "toc anchor matches heading id" 'href="#a-code-block"' "$(body /intro/)"
check "previous/next pager" "class=\"pager\"" "$(body /intro/)"
check "highlighted comment" '<span class="c">' "$(body /intro/)"
check "highlighted keyword" '<span class="k">' "$(body /intro/)"
check "code block title" "<figcaption>Output</figcaption>" "$(body /intro/)"

# ── The static export: assets, nested included ─────────────────────────
# The export must copy the book's asset directories whole, and must not
# re-read the top level while descending (which wrote 0-byte files).
rm -rf "$T/dist"
if "$T/resid-book" export examples/sample/book.toml "$T/dist" >/dev/null 2>&1; then
    for f in index.html intro/index.html numbers/index.html mascot.svg nested.svg img/mark.svg book.js; do
        [ -s "$T/dist/$f" ] && ok || bad "export missing or empty: $f"
    done
    # .nojekyll is a marker: it must exist, and must be empty.
    [ -f "$T/dist/.nojekyll" ] && ok || bad "export missing: .nojekyll"
else
    bad "export failed"
fi
# Every image a page references must exist in the export, and be non-empty.
for r in $(grep -rhoE '\(/(img/)?[A-Za-z0-9_./-]+\.svg\)' examples/sample/src/content/docs | tr -d '()' | sort -u); do
    [ -s "$T/dist${r}" ] && ok || bad "referenced asset not exported: $r"
done

# ── Live search (a Datastar GET) ───────────────────────────────────────
SIG="$(python3 -c 'import urllib.parse;print(urllib.parse.quote("{\"q\":\"decimals\"}"))')"
check "search finds a page" "Numbers" "$(curl -s -H 'Datastar-Request: true' "http://127.0.0.1:$PORT/ui/search?datastar=$SIG")"
check "search emits a patch event" "datastar-patch-elements" "$(curl -s -H 'Datastar-Request: true' "http://127.0.0.1:$PORT/ui/search?datastar=$SIG")"

echo "resid-book: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
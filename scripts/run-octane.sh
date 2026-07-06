#!/usr/bin/env bash
#
# Run the Octane benchmark suite (chromium/octane) on the lumen engine.
# Expects Octane to already exist as a sibling ../octane checkout, or set OCTANE
# to the directory containing base.js and run.js. Builds the `lumen` CLI in
# release mode (unless LUMEN_BIN points at a prebuilt binary), then prints
# per-benchmark scores plus the composite score. Higher is better.
#
#   scripts/run-octane.sh                    # full suite
#   scripts/run-octane.sh richards crypto    # selected benchmarks
#   OCTANE=/path/to/octane scripts/run-octane.sh gbemu
#   LUMEN_BIN=/path/to/lumen scripts/run-octane.sh   # skip the build, use this binary
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/bench.sh
. "$ROOT/scripts/lib/bench.sh"
OCTANE="${OCTANE:-$ROOT/../octane}"

if [ ! -d "$OCTANE" ] || [ ! -f "$OCTANE/base.js" ] || [ ! -f "$OCTANE/run.js" ]; then
  echo "error: Octane not found at $OCTANE (need base.js and run.js)." >&2
  echo "Set \$OCTANE, or clone it as a sibling checkout:" >&2
  echo "  git clone https://github.com/chromium/octane \"$OCTANE\"" >&2
  exit 1
fi

# The benchmark files and their order come straight from Octane's own run.js
# `load()` manifest, so the runnable set tracks upstream instead of a hardcoded
# table. base.js is the harness (added separately, first); the rest are benchmarks.
MANIFEST=()
while IFS= read -r f; do
  [ "$f" = "base.js" ] && continue
  MANIFEST+=("$f")
done < <(sed -n "s/^load([^']*'\([^']*\.js\)').*/\1/p" "$OCTANE/run.js")

if [ ${#MANIFEST[@]} -eq 0 ]; then
  echo "error: no load('...js') entries found in $OCTANE/run.js" >&2
  exit 1
fi

# Expand and validate the requested suites into a file list *before* building, so
# a typo fails in milliseconds instead of after a multi-minute release build. A
# suite name matches its own file plus any hyphenated parts — `zlib` picks up
# zlib.js + zlib-data.js, `gbemu` picks up gbemu-part1.js + gbemu-part2.js — and
# a trailing `.js` (e.g. from tab-completion) is tolerated.
SUITE_FILES=()
if [ $# -ge 1 ]; then
  for arg in "$@"; do
    name="${arg%.js}"
    matched=0
    for f in "${MANIFEST[@]}"; do
      case "$f" in
        "$name.js" | "$name"-*.js)
          SUITE_FILES+=("$OCTANE/$f")
          matched=1
          ;;
      esac
    done
    if [ "$matched" -eq 0 ]; then
      echo "error: unknown Octane suite '$arg' (no matching file in $OCTANE/run.js)" >&2
      exit 1
    fi
  done
else
  for f in "${MANIFEST[@]}"; do
    SUITE_FILES+=("$OCTANE/$f")
  done
fi

LUMEN_BIN="$(bench_lumen_bin "$ROOT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DRIVER="$WORK/octane-driver.js"
OUTPUT="$WORK/octane-output"

bench_strip_load "$OCTANE/run.js" "$DRIVER"

ARGS=("$OCTANE/base.js" "${SUITE_FILES[@]}" "$DRIVER")

set +e
"$LUMEN_BIN" "${ARGS[@]}" 2>&1 | tee "$OUTPUT"
status=${PIPESTATUS[0]}
set -e

if grep -Eq '^[[:alnum:]_-]+: [[:alpha:]]*Error:' "$OUTPUT"; then
  echo "error: Octane reported benchmark failure." >&2
  status=1
fi

if [ "$status" -eq 0 ] && ! grep -Eq '^Score \(version [0-9]+\): ' "$OUTPUT"; then
  echo "error: Octane completed without reporting a score." >&2
  status=1
fi

exit "$status"

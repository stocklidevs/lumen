#!/usr/bin/env bash
#
# Run the classic V8 benchmark suite (v8-v7, from mozilla/arewefastyet) on the lumen engine.
# Downloads the benchmark JS into ./v8-v7 (gitignored) on first run, builds the `lumen` CLI in
# release mode, and prints per-benchmark scores plus the composite score. Higher is better;
# scores are normalized to a 2008 reference machine at 100.
#
#   scripts/run-v8bench.sh              # full suite
#   scripts/run-v8bench.sh richards     # one benchmark (any of the .js basenames)
#   LUMEN_BIN=/path/to/lumen scripts/run-v8bench.sh   # skip the build, use this binary
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/bench.sh
. "$ROOT/scripts/lib/bench.sh"
DEST="$ROOT/v8-v7"
RAW="https://raw.githubusercontent.com/mozilla/arewefastyet/master/benchmarks/v8-v7"
FILES=(base.js richards.js deltablue.js crypto.js raytrace.js earley-boyer.js regexp.js splay.js navier-stokes.js run.js)

if [ ! -f "$DEST/base.js" ]; then
  echo "Downloading v8-v7 benchmark into $DEST ..."
  mkdir -p "$DEST"
  for f in "${FILES[@]}"; do
    curl -fsSL "$RAW/$f" -o "$DEST/$f"
  done
fi

# The upstream driver uses the shell `load()`; the lumen CLI takes files in sequence instead.
bench_strip_load "$DEST/run.js" "$DEST/driver.js"

if [ $# -ge 1 ]; then
  SUITES=("$@")
else
  SUITES=(richards deltablue crypto raytrace earley-boyer regexp splay navier-stokes)
fi

ARGS=("$DEST/base.js")
for s in "${SUITES[@]}"; do
  ARGS+=("$DEST/${s%.js}.js")
done
ARGS+=("$DEST/driver.js")

LUMEN_BIN="$(bench_lumen_bin "$ROOT")"
exec "$LUMEN_BIN" "${ARGS[@]}"

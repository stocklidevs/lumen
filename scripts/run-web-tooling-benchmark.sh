#!/usr/bin/env bash
#
# Run V8's Web Tooling Benchmark (v8/web-tooling-benchmark) on the lumen engine.
# Expects the benchmark to exist as a sibling ../web-tooling-benchmark checkout,
# or set WEB_TOOLING_BENCHMARK_DIR to the directory containing the built
# dist/cli.js bundle. Builds the node-style `lumen-cli` engine in release mode
# (unless LUMEN_BIN points at a prebuilt binary), then runs the benchmark and
# prints its per-tool scores plus the composite (geometric mean). Higher is
# better.
#
#   scripts/run-web-tooling-benchmark.sh
#   WEB_TOOLING_BENCHMARK_DIR=/path/to/checkout scripts/run-web-tooling-benchmark.sh
#   LUMEN_BIN=/path/to/lumen-cli scripts/run-web-tooling-benchmark.sh   # skip the build
#
# Engine: lumen-cli (node/deno-style entry) runs the self-contained dist/cli.js
# bundle. The local benchmark checkout documents direct `node dist/cli.js` and
# shell-engine `dist/cli.js` invocations, and its CLI prints `Geometric mean:`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="${WEB_TOOLING_BENCHMARK_DIR:-$ROOT/../web-tooling-benchmark}"
BUNDLE="$BENCH/dist/cli.js"

# Validate the checkout before building anything with cargo, so a missing or
# unbuilt benchmark fails in milliseconds with an actionable message.
if [ ! -d "$BENCH" ]; then
  echo "error: web-tooling-benchmark not found at $BENCH." >&2
  echo "Set \$WEB_TOOLING_BENCHMARK_DIR, or clone it as a sibling checkout:" >&2
  echo "  git clone https://github.com/v8/web-tooling-benchmark \"$BENCH\"" >&2
  exit 1
fi

if [ ! -f "$BUNDLE" ]; then
  echo "error: web-tooling-benchmark run bundle not found at $BUNDLE." >&2
  echo "Build it first (installs deps and bundles dist/cli.js):" >&2
  echo "  cd ../web-tooling-benchmark && npm install" >&2
  echo "  (Windows: cd ..\\web-tooling-benchmark && npm.cmd install)" >&2
  exit 1
fi

# Build the node-style CLI in release mode unless the caller supplied a prebuilt
# binary. LUMEN_BIN is used verbatim and no build is attempted.
if [ -z "${LUMEN_BIN:-}" ]; then
  cargo build --release -q -p lumen-cli
  LUMEN_BIN="$ROOT/target/release/lumen-cli"
fi

# Capture output so we can confirm a real score was produced. Scratch lives under
# the gitignored target/ dir; the runner never writes into the benchmark checkout.
OUTPUT_REL="$(cd "$ROOT" && mkdir -p target && mktemp "target/run-web-tooling-benchmark.XXXXXX")"
OUTPUT="$ROOT/$OUTPUT_REL"
trap 'rm -f "$OUTPUT"' EXIT

set +e
"$LUMEN_BIN" "$BUNDLE" "$@" 2>&1 | tee "$OUTPUT"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ]; then
  echo "error: web-tooling-benchmark reported benchmark failure." >&2
elif ! grep -Eq 'Geometric mean:' "$OUTPUT"; then
  echo "error: web-tooling-benchmark completed without reporting a score." >&2
  status=1
fi

exit "$status"

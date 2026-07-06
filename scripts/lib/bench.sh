# Shared helpers for the benchmark runners (run-octane.sh, run-v8bench.sh).
# Sourced, not executed. The caller owns `set -euo pipefail` and $ROOT.

# Resolve the lumen CLI to run: honor a caller-supplied $LUMEN_BIN (skip the
# build, e.g. to benchmark a nightly binary), otherwise build the release binary.
# Prints the binary path; cargo's own output goes to stderr so it can't taint it.
#   lumen="$(bench_lumen_bin "$ROOT")"
bench_lumen_bin() {
  local root="$1"
  if [ -n "${LUMEN_BIN:-}" ]; then
    printf '%s\n' "$LUMEN_BIN"
    return 0
  fi
  cargo build --release -q -p lumen --bin lumen 1>&2
  printf '%s\n' "$root/target/release/lumen"
}

# Turn an upstream benchmark run.js into a driver the lumen CLI can execute: the
# upstream driver pulls files in with the shell `load()`, but the CLI takes them
# as arguments instead, so strip the `load(...)` lines.
#   bench_strip_load "$RUN_JS" "$DRIVER"
bench_strip_load() {
  sed '/^load(/d' "$1" > "$2"
}

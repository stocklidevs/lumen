#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SCRIPT="$ROOT/scripts/run-web-tooling-benchmark.sh"
TMP_ROOT="target/run-web-tooling-benchmark-tests"
TMP="$TMP_ROOT/$$"
FAKE_BENCH="$TMP/web-tooling-benchmark"
FAKE_BIN="$TMP/bin"
CARGO_LOG="$TMP/cargo.log"
LUMEN_LOG="$TMP/lumen.args"
STDERR_LOG="$TMP/stderr.log"
# The lumen stub lives in the test's own tmp dir and is passed via LUMEN_BIN, so
# the runner never builds or touches the real target/release/lumen-cli artifact.
LUMEN_STUB="$FAKE_BIN/lumen-cli"

fail() {
  echo "not ok - $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "expected to find: $needle" >&2
    echo "in: $file" >&2
    echo "--- file contents ---" >&2
    cat "$file" >&2
    fail "missing expected text"
  fi
}

assert_file_equals() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(cat "$file")"
  if [ "$actual" != "$expected" ]; then
    echo "--- expected ---" >&2
    printf '%s\n' "$expected" >&2
    echo "--- actual ---" >&2
    printf '%s\n' "$actual" >&2
    fail "$file did not match expected contents"
  fi
}

cleanup() {
  rm -rf "$TMP"
}

setup_stubs() {
  mkdir -p "$TMP_ROOT" "$FAKE_BIN"

  cat > "$FAKE_BIN/cargo" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CARGO_LOG"
exit 0
SH
  chmod +x "$FAKE_BIN/cargo"

  cat > "$LUMEN_STUB" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$LUMEN_LOG"
if [ -n "${LUMEN_STUB_OUTPUT:-}" ]; then
  printf '%s\n' "$LUMEN_STUB_OUTPUT"
elif [ "${LUMEN_STUB_NO_SCORE:-0}" -eq 0 ]; then
  printf '%s\n' '     Geometric mean:  1.00 runs/s'
fi
exit "${LUMEN_STUB_EXIT:-0}"
SH
  chmod +x "$LUMEN_STUB"

  export CARGO_LOG LUMEN_LOG
  export PATH="$FAKE_BIN:$PATH"
}

write_fake_bench() {
  rm -rf "$FAKE_BENCH"
  mkdir -p "$FAKE_BENCH/dist"
  printf 'fake bundle\n' > "$FAKE_BENCH/dist/cli.js"
}

run_expect_failure() {
  local status=0
  "$@" > "$TMP/stdout.log" 2> "$STDERR_LOG" || status=$?
  if [ "$status" -eq 0 ]; then
    fail "command unexpectedly succeeded: $*"
  fi
}

test_missing_checkout_errors_before_build() {
  run_expect_failure env WEB_TOOLING_BENCHMARK_DIR="$TMP/missing-bench" "$SCRIPT"

  assert_contains "$STDERR_LOG" "error: web-tooling-benchmark not found at $TMP/missing-bench"
  assert_contains "$STDERR_LOG" "git clone https://github.com/v8/web-tooling-benchmark \"$TMP/missing-bench\""
  if [ -f "$CARGO_LOG" ]; then
    fail "cargo should not run when the benchmark checkout is missing"
  fi
}

test_missing_bundle_prints_build_hint_before_build() {
  rm -rf "$FAKE_BENCH"
  mkdir -p "$FAKE_BENCH"
  run_expect_failure env WEB_TOOLING_BENCHMARK_DIR="$FAKE_BENCH" "$SCRIPT"

  assert_contains "$STDERR_LOG" "run bundle not found at $FAKE_BENCH/dist/cli.js"
  assert_contains "$STDERR_LOG" "cd ../web-tooling-benchmark && npm install"
  assert_contains "$STDERR_LOG" "cd ..\\web-tooling-benchmark && npm.cmd install"
  if [ -f "$CARGO_LOG" ]; then
    fail "cargo should not run when the run bundle is missing"
  fi
}

test_lumen_bin_skips_build_and_forwards_args() {
  write_fake_bench
  env WEB_TOOLING_BENCHMARK_DIR="$FAKE_BENCH" LUMEN_BIN="$LUMEN_STUB" "$SCRIPT" --foo bar \
    > "$TMP/stdout.log"

  assert_file_equals "$LUMEN_LOG" "$FAKE_BENCH/dist/cli.js
--foo
bar"
  if [ -f "$CARGO_LOG" ]; then
    fail "cargo must not run when LUMEN_BIN is provided"
  fi
}

test_nonzero_exit_is_failure() {
  write_fake_bench
  run_expect_failure env WEB_TOOLING_BENCHMARK_DIR="$FAKE_BENCH" LUMEN_BIN="$LUMEN_STUB" \
    LUMEN_STUB_EXIT=3 "$SCRIPT"

  assert_contains "$STDERR_LOG" "error: web-tooling-benchmark reported benchmark failure."
}

test_missing_score_is_failure() {
  write_fake_bench
  run_expect_failure env WEB_TOOLING_BENCHMARK_DIR="$FAKE_BENCH" LUMEN_BIN="$LUMEN_STUB" \
    LUMEN_STUB_NO_SCORE=1 "$SCRIPT"

  assert_contains "$STDERR_LOG" "error: web-tooling-benchmark completed without reporting a score."
}

trap cleanup EXIT
setup_stubs

test_missing_checkout_errors_before_build
test_missing_bundle_prints_build_hint_before_build
test_lumen_bin_skips_build_and_forwards_args
test_nonzero_exit_is_failure
test_missing_score_is_failure

echo "ok - run-web-tooling-benchmark"

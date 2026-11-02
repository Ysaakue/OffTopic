#!/usr/bin/env bash
# Builds and tests the C++ voice core on Linux (WSL):
#   1. debug build + tests (GCC)
#   2. AddressSanitizer + UBSan and ThreadSanitizer builds + tests (clang)
#   3. coverage build + tests, gated by gcovr
#   4. a short libFuzzer campaign for every registered fuzz target
#   5. a short loopback_sim run (lossy localhost link) as an end-to-end smoke test
#
# Usage: tools/verify_core.sh            (from the repository root, inside WSL)
# Env:   VC_FUZZ_SECONDS  seconds per fuzz target (default 30)
set -euo pipefail

readonly LINE_THRESHOLD=95
readonly BRANCH_THRESHOLD=90
readonly FUZZ_SECONDS="${VC_FUZZ_SECONDS:-30}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly core_dir="$repo_root/packages/voice_core"
readonly build_root="$HOME/.cache/offtopic/voice_core"
readonly report_dir="$core_dir/build/coverage"

# pipx installs cmake and gcovr here.
export PATH="$HOME/.local/bin:$PATH"

step() { printf '\n==> %s\n' "$*"; }

require_tools() {
  local missing=()
  for tool in cmake ninja gcc g++ clang clang++ gcovr; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if ((${#missing[@]} > 0)); then
    echo "Missing tools: ${missing[*]}. See docs/DEPENDENCIES.md." >&2
    exit 1
  fi
}

run_preset() {
  local preset="$1"
  step "[$preset] configure, build and test"
  (cd "$core_dir" && cmake --preset "$preset" >/dev/null && cmake --build --preset "$preset" && ctest --preset "$preset")
}

run_coverage() {
  local preset="desktop-coverage"
  # Start from clean counters so the report reflects this run only.
  if [[ -d "$build_root/$preset" ]]; then
    find "$build_root/$preset" -name '*.gcda' -delete
  fi
  run_preset "$preset"

  step "[$preset] gcovr gate (lines >= ${LINE_THRESHOLD}%, branches >= ${BRANCH_THRESHOLD}%)"
  mkdir -p "$report_dir"
  gcovr \
    --root "$core_dir" \
    --filter "$core_dir/src/" \
    --exclude "$core_dir/src/platform/android/" \
    --exclude-unreachable-branches \
    --exclude-throw-branches \
    --print-summary \
    --html-details "$report_dir/index.html" \
    --fail-under-line "$LINE_THRESHOLD" \
    --fail-under-branch "$BRANCH_THRESHOLD" \
    "$build_root/$preset"
  echo "HTML report: packages/voice_core/build/coverage/index.html"
}

run_fuzzers() {
  local preset="desktop-fuzz"
  step "[$preset] configure and build"
  (cd "$core_dir" && cmake --preset "$preset" >/dev/null && cmake --build --preset "$preset")

  local list_file="$build_root/$preset/fuzz_targets.txt"
  local targets=""
  [[ -f "$list_file" ]] && targets="$(tr ';' ' ' <"$list_file")"
  if [[ -z "${targets// /}" ]]; then
    echo "No fuzz targets registered yet."
    return
  fi

  for target in $targets; do
    step "[$preset] $target for ${FUZZ_SECONDS}s"
    local work_corpus
    work_corpus="$(mktemp -d)"
    local seed_corpus="$core_dir/tests/fuzz/corpus/$target"
    local binary
    binary="$(find "$build_root/$preset" -type f -name "$target" -perm -u+x | head -n 1)"
    if [[ -d "$seed_corpus" ]]; then
      "$binary" -max_total_time="$FUZZ_SECONDS" "$work_corpus" "$seed_corpus"
    else
      "$binary" -max_total_time="$FUZZ_SECONDS" "$work_corpus"
    fi
    rm -rf "$work_corpus"
  done
}

run_loopback() {
  step "[desktop-debug] loopback_sim: 6 s, 5 % loss, 0..30 ms jitter, 2 % reorder"
  "$build_root/desktop-debug/loopback_sim/loopback_sim" \
    --seconds=6 --loss=0.05 --jitter-ms=30 --reorder=0.02 --seed=7
}

main() {
  require_tools
  run_preset desktop-debug
  run_loopback
  run_preset desktop-asan
  run_preset desktop-tsan
  run_coverage
  run_fuzzers
  step "voice core: all checks passed"
}

main "$@"

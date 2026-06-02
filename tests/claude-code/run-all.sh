#!/usr/bin/env bash
# Run all fast qualitative tests and report a summary.
# Exit code 0 = all passed, non-zero = at least one failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
  local script="$1"
  local name
  name="$(basename "$script" .sh)"
  echo ""
  echo "────────────────────────────────────────"
  if bash "$script"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name")
  fi
}

echo "=== pinky-swear fast qualitative tests ==="

run_test "$SCRIPT_DIR/test-api-contract-check-import-hint.sh"
run_test "$SCRIPT_DIR/test-api-spec-import-modes.sh"
run_test "$SCRIPT_DIR/test-api-spec-import-version-bump.sh"
run_test "$SCRIPT_DIR/test-api-change-guardian-triggers.sh"
run_test "$SCRIPT_DIR/test-brainstorming-external-hook.sh"

echo ""
echo "════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done
  exit 1
fi

echo "All fast tests passed."

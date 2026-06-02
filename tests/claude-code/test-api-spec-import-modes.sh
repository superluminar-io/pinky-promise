#!/usr/bin/env bash
# Test: api-spec-import modes behave correctly on re-import
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-spec-import modes ==="
echo ""

echo "Test 1: --auto re-import shows a diff..."
output=$(run_claude "Invoke the api-spec-import skill and then answer: what does --auto mode show the user when re-importing a spec that already has a registry entry?")

assert_contains "$output" "diff|previously declared|no longer detected|newly detected" "Shows a diff on re-import" || exit 1

echo ""
echo "Test 2: --subset re-import pre-selects previous operations..."
output=$(run_claude "Invoke the api-spec-import skill and then answer: on a re-import, what is pre-selected in the --subset selection dialog?")

assert_contains "$output" "pre-select|previously declared|previous.*operations|existing.*operations" "Pre-selects previously declared operations" || exit 1

echo ""
echo "Test 3: --full re-import skips selection..."
output=$(run_claude "Invoke the api-spec-import skill and then answer: in --full mode, does the user get a selection step to choose which operations to import?")

assert_contains "$output" "no|not|without|skip|none|all.*operations" "No selection step for --full" || exit 1

echo ""
echo "=== All api-spec-import modes tests passed ==="

#!/usr/bin/env bash
# Test: api-spec-import modes behave correctly on re-import
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-spec-import modes ==="
echo ""

echo "Test 1: --auto re-import shows a diff..."
output=$(run_claude "In api-spec-import, what does --auto mode show the user when re-importing a spec that already has a registry entry?")

assert_contains "$output" "diff|previously declared|no longer detected|newly detected" "Shows a diff on re-import" || exit 1

echo ""
echo "Test 2: --subset re-import pre-selects previous operations..."
output=$(run_claude "In api-spec-import, what is pre-selected in the --subset selection dialog when re-importing a spec that already has a registry entry?")

assert_contains "$output" "pre-select|previously declared|existing" "Pre-selects previously declared operations" || exit 1

echo ""
echo "Test 3: --full re-import overwrites without selection..."
output=$(run_claude "In api-spec-import --full mode, is there a selection dialog shown to the user?")

assert_not_contains "$output" "selection dialog|choose|select operations" "No selection dialog for --full" || exit 1
assert_contains "$output" "all operations|everything|no.*selection|without.*select" "Imports all without selection" || exit 1

echo ""
echo "=== All api-spec-import modes tests passed ==="

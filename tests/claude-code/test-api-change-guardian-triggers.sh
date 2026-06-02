#!/usr/bin/env bash
# Test: api-change-guardian triggers on interface-changing phrases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-change-guardian triggers ==="
echo ""

echo "Test 1: Type change phrase triggers guardian..."
output=$(run_claude "According to pinky-swear, should api-change-guardian be invoked if someone says 'change the parameter type to string'?")

assert_contains "$output" "yes|should|must|invoke|trigger" "Type change triggers guardian" || exit 1

echo ""
echo "Test 2: Operation removal triggers guardian..."
output=$(run_claude "According to pinky-swear, should api-change-guardian be invoked if someone says 'remove this endpoint'?")

assert_contains "$output" "yes|should|must|invoke|trigger" "Operation removal triggers guardian" || exit 1

echo ""
echo "Test 3: Internal refactor does NOT require guardian..."
output=$(run_claude "According to pinky-swear, should api-change-guardian be invoked if a developer refactors a private internal helper function that is not part of the public API?")

assert_contains "$output" "no|not.*invoke|not.*trigger|not.*required|only.*public|internal" "Internal refactor does not trigger guardian" || exit 1

echo ""
echo "Test 4: Guardian triggers on response shape change..."
output=$(run_claude "According to pinky-swear, should api-change-guardian be invoked if someone says 'change the response shape of getUserById to include a roles array'?")

assert_contains "$output" "yes|should|must|invoke|trigger" "Response shape change triggers guardian" || exit 1

echo ""
echo "=== All api-change-guardian trigger tests passed ==="

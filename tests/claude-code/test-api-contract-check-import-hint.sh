#!/usr/bin/env bash
# Test: api-contract-check surfaces /api-spec-import for unknown services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-contract-check import hint ==="
echo ""

echo "Test 1: Import suggestion present in unknown-service handling..."
output=$(run_claude "Invoke the api-contract-check skill and then answer: what should happen when a service being checked has no entry in the registry?")

assert_contains "$output" "/api-spec-import" "Mentions /api-spec-import command" || exit 1
assert_contains "$output" "register|import|add.*registry" "Suggests registering the service" || exit 1

echo ""
echo "Test 2: Suggestion does not silently skip..."
assert_not_contains "$output" "silently skip|ignore" "Does not say to silently skip" || exit 1

echo ""
echo "=== All api-contract-check import hint tests passed ==="

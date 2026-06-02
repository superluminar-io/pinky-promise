#!/usr/bin/env bash
# Test: CLAUDE.md brainstorming hook surfaces import suggestion for external services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: brainstorming external service hook ==="
echo ""

echo "Test 1: Import suggestion fires for unregistered external service..."
output=$(run_claude "According to pinky-swear's CLAUDE.md instructions (load them if needed), what should happen during a brainstorming session if the design mentions calling the Stripe API but there is no registry entry for stripe-api?")

assert_contains "$output" "/api-spec-import" "Mentions /api-spec-import command" || exit 1
assert_contains "$output" "before.*planning|before.*plan|before.*finaliz|conclude|register" "Surfaces before brainstorm concludes" || exit 1

echo ""
echo "Test 2: Hook applies to writing-plans too..."
output=$(run_claude "According to pinky-swear's CLAUDE.md instructions (load them if needed), what should happen when writing a plan that includes a step to call an external service with no registry entry?")

assert_contains "$output" "/api-spec-import" "Mentions /api-spec-import in planning context" || exit 1
assert_contains "$output" "before.*finaliz|before.*plan|register" "Blocks plan finalization" || exit 1

echo ""
echo "=== All brainstorming external hook tests passed ==="

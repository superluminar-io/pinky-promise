#!/usr/bin/env bash
# Test: api-spec-publish skill behaviour
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-spec-publish ==="
echo ""

echo "Test 1: No draft spec → invokes api-spec-brainstorming first..."
output=$(run_claude "Invoke the api-spec-publish skill and then answer: what does it do if there is no draft spec in the conversation context?")

assert_contains "$output" "api-spec-brainstorming" "Falls back to api-spec-brainstorming when no draft present" || exit 1

echo ""
echo "Test 2: Unresolved deferred decisions block publish..."
output=$(run_claude "Invoke the api-spec-publish skill and then answer: what happens if there are unresolved deferred decisions from a previous api-change-guardian run?")

assert_contains "$output" "cannot publish|block|must be resolved|unresolved|deferred" "Blocks publish on unresolved guardian decisions" || exit 1

echo ""
echo "Test 3: Missing API_REGISTRY_REPO stops the skill cleanly..."
output=$(run_claude "Invoke the api-spec-publish skill and then answer: what does it do if API_REGISTRY_REPO is not configured anywhere?")

assert_contains "$output" "cannot publish|not configured|registry-setup" "Stops cleanly when registry not configured" || exit 1
assert_not_contains "$output" "successfully published|pushed to registry|git push origin|published.*registry" "Does not attempt to push without registry config" || exit 1

echo ""
echo "Test 4: First-time publish uses version 1.0.0..."
output=$(run_claude "Invoke the api-spec-publish skill and then answer: what version number is used when publishing a service for the very first time?")

assert_contains "$output" "1\.0\.0" "First publish uses version 1.0.0" || exit 1

echo ""
echo "Test 5: User confirmation required before pushing..."
output=$(run_claude "Invoke the api-spec-publish skill and then answer: does it push to the registry immediately, or does it ask for confirmation first?")

assert_contains "$output" "confirm|yes.*no|ask|prompt" "Asks for confirmation before pushing" || exit 1
assert_not_contains "$output" "push.*immediately|without.*confirm" "Does not push without confirmation" || exit 1

echo ""
echo "=== All api-spec-publish tests passed ==="

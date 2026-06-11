#!/usr/bin/env bash
# Test: api-pact-generate skill behaviour
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-pact-generate ==="
echo ""

# ── Role detection ────────────────────────────────────────────────────────────

echo "Test 1: Consumer-only project (imported spec, no draft-spec) → auto-detects, no question..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`.pinky-promise/bedrock-runtime-openapi.json\` exists but there is no \`.pinky-promise/draft-spec.json\`, does it ask the user their role or auto-detect it as consumer?")

assert_contains "$output" "auto.detect|no.*question|consumer.*only|detected.*consumer|without asking" \
  "Auto-detects consumer when only imported specs present" || exit 1

echo ""
echo "Test 2: Provider-only project (draft-spec, no imports) → auto-detects, no question..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`.pinky-promise/draft-spec.json\` exists but there are no imported specs and no api-dependencies.json, does it ask the user their role or auto-detect it as provider?")

assert_contains "$output" "auto.detect|no.*question|provider.*only|detected.*provider|without asking" \
  "Auto-detects provider when only draft-spec present" || exit 1

echo ""
echo "Test 3: Both signals → asks with multi-select and clarifying message..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if both \`.pinky-promise/draft-spec.json\` AND \`.pinky-promise/github-openapi.json\` exist, what does it ask the user, and is it single-select or multi-select?")

assert_contains "$output" "multi.select|multiple.*select|select.*multiple|both.*options|check.*box" \
  "Uses multi-select when both signals present" || exit 1
assert_contains "$output" "detected.*both|both.*detected|draft.*spec.*imported|imported.*draft" \
  "Clarifies that both signals were detected" || exit 1

echo ""
echo "Test 4: Neither signal → asks (no auto-detection)..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if there is no draft-spec.json and no imported specs and no api-dependencies.json, does it ask the user their role?")

assert_contains "$output" "ask|prompt|question|role" \
  "Asks when no signals found" || exit 1
assert_not_contains "$output" "auto.detect|without asking|skips.*question" \
  "Does not auto-detect with no signals" || exit 1

echo ""
echo "Test 5: Existing consumer test file → offers update flow, not regenerate..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`pact_consumer_test.go\` already exists in the project, does it offer to update the existing tests or does it regenerate them from scratch?")

assert_contains "$output" "update|review.*existing|existing.*test|propose.*change|delta|one.*by.*one|individually" \
  "Offers update flow when consumer tests already exist" || exit 1
assert_not_contains "$output" "will regenerat|does regenerat|always regenerat|regenerat.*without|silently.*regenerat" \
  "Does not silently regenerate from scratch" || exit 1

echo ""
echo "Test 6: Existing consumer tests + provider signal → offers both update and add provider..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`pact_consumer_test.go\` already exists AND \`.pinky-promise/draft-spec.json\` also exists, what options does it present to the user?")

assert_contains "$output" "update.*consumer|consumer.*update" \
  "Offers to update existing consumer tests" || exit 1
assert_contains "$output" "add.*provider|provider.*test|generate.*provider" \
  "Offers to add provider tests" || exit 1

# ── Provider self-validation ──────────────────────────────────────────────────

echo ""
echo "Test 7: Provider path → multi-select for both validation patterns..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: when generating provider tests, does it ask the user to choose between self-validation and consumer pact validation as a single-select or multi-select? Can the user pick both?")

assert_contains "$output" "multi.select|multiple.*select|both.*options|select.*both|can.*choose.*both" \
  "Provider pattern selection is multi-select" || exit 1

echo ""
echo "Test 8: Self-validation needs no Pact Broker..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: what is the self-validation pattern and does it require a Pact Broker?")

assert_contains "$output" "no.*broker|without.*broker|broker.*not.*required|no pact broker" \
  "Self-validation requires no Pact Broker" || exit 1
assert_contains "$output" "spec.*contract|spec.*source.*truth|spec.*covers" \
  "Explains why spec is sufficient" || exit 1

# ── Anti-hallucination framing ────────────────────────────────────────────────

echo ""
echo "Test 9: Step 6 announce mentions spec-enforcement guarantee..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: after generating consumer tests, what does the announce say about what happens if client code accesses a field not in the spec?")

assert_contains "$output" "fail|test.*fail|cause.*failure|test.*catch" \
  "Announce explains test failure on non-spec field access" || exit 1
assert_contains "$output" "hallucin|non.spec|not.*in.*spec|only.*spec|spec.*enforc|anti.hallucin" \
  "Announce references anti-hallucination guarantee" || exit 1

echo ""
echo "Test 10: Generated test file includes spec-enforcement comment..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: what comment is added at the top of the generated pact_consumer_test.go file and what is its purpose?")

assert_contains "$output" "comment|explains|purpose" \
  "A comment is added at the top of the generated file" || exit 1
assert_contains "$output" "spec.*contract|contract.*spec|enforce|only.*declared|declared.*spec" \
  "Comment explains spec-enforcement purpose" || exit 1

# ── Terminology ───────────────────────────────────────────────────────────────

echo ""
echo "Test 11: Skill uses 'validation' not 'verification' in user-facing text..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: in the multi-select it shows the user for provider test setup, what are the exact option labels? List them only — do not explain.")

assert_contains "$output" "validation" \
  "Uses validation in user-facing text" || exit 1
assert_not_contains "$output" "^verification|option.*verification|label.*verification" \
  "Does not use verification in user-facing text" || exit 1

echo ""
echo "=== All api-pact-generate tests passed ==="

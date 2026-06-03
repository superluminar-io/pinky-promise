#!/usr/bin/env bash
# Test: api-spec-brainstorming skill produces correct IDL output format
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-spec-brainstorming ==="
echo ""

echo "Test 1: Contract output includes pinkySwearVersion..."
output=$(run_claude "Invoke the api-spec-brainstorming skill and then answer: what is the first field in the contract JSON it produces?")

assert_contains "$output" "pinkySwearVersion" "Contract includes pinkySwearVersion field" || exit 1

echo ""
echo "Test 2: Contract has no bindings field..."
output=$(run_claude "Invoke the api-spec-brainstorming skill and then answer: does the contract JSON file include a bindings field?")

assert_not_contains "$output" "yes.*bindings|bindings.*yes|includes.*bindings|contains.*bindings" "Contract does not include bindings" || exit 1

echo ""
echo "Test 3: Bindings are written to a separate file..."
output=$(run_claude "Invoke the api-spec-brainstorming skill and then answer: where are bindings stored — in the same file as the contract or separately?")

assert_contains "$output" "separate|bindings\.json|different file" "Bindings are in a separate file" || exit 1

echo ""
echo "Test 4: Draft is persisted to .pinky-swear/..."
output=$(run_claude "Invoke the api-spec-brainstorming skill and then answer: where does it write the draft contract and bindings to disk?")

assert_contains "$output" "\.pinky-swear" "Draft written to .pinky-swear/ directory" || exit 1

echo ""
echo "Test 5: object/enum/union must be named types, not inline..."
output=$(run_claude "Invoke the api-spec-brainstorming skill and then answer: can object, enum, or union types appear inline in input/output fields?")

assert_contains "$output" "no|cannot|must.*named|named.*types|not.*inline" "object/enum/union must be named types" || exit 1

echo ""
echo "=== All api-spec-brainstorming tests passed ==="

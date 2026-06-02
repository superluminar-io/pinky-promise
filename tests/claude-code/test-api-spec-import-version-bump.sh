#!/usr/bin/env bash
# Test: api-spec-import version bump rules, including tie-break
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-spec-import version bump rules ==="
echo ""

echo "Test 1: Additions only → minor bump..."
output=$(run_claude "In api-spec-import, if a re-import adds two new operations and changes nothing else, what version bump is proposed?")

assert_contains "$output" "minor" "Additions only → minor bump" || exit 1

echo ""
echo "Test 2: Removal → major bump..."
output=$(run_claude "In api-spec-import, if a re-import removes one operation, what version bump is proposed?")

assert_contains "$output" "major" "Removal → major bump" || exit 1

echo ""
echo "Test 3: Tie-break: both additions and removals → major wins..."
output=$(run_claude "In api-spec-import, if a re-import adds two operations and removes one operation in the same import, what version bump is proposed and why?")

assert_contains "$output" "major" "Mixed add+remove → major bump" || exit 1
assert_contains "$output" "most.breaking|removal|precedence|tie.break|wins" "Cites tie-break rule" || exit 1

echo ""
echo "Test 4: Metadata-only → patch bump..."
output=$(run_claude "In api-spec-import, if a re-import only updates operation descriptions with no structural changes, what version bump is proposed?")

assert_contains "$output" "patch" "Metadata-only → patch bump" || exit 1

echo ""
echo "=== All api-spec-import version bump tests passed ==="

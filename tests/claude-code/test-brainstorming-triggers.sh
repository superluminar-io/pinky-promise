#!/usr/bin/env bash
# Test: api-spec-brainstorming fires alongside superpowers:brainstorming
#
# Uses --plugin-dir to load the plugin, then checks that a brainstorm
# prompt triggers BOTH superpowers:brainstorming AND
# pinky-swear:api-spec-brainstorming in the same response.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: brainstorming trigger ==="
echo ""

OUTPUT_FILE=$(mktemp)

API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
claude -p "I want to build a url-shortener service. It shall shorten URLs, resolve short codes, and send a notification when a URL expires. Let's brainstorm." \
  --verbose \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --max-turns 3 \
  --output-format stream-json \
  > "$OUTPUT_FILE" 2>&1 || true

PASS=true

echo "Test 1: superpowers:brainstorming fires..."
if grep -qE '"skill":"([^"]*:)?brainstorming"' "$OUTPUT_FILE"; then
  echo "  [PASS] superpowers:brainstorming triggered"
else
  echo "  [FAIL] superpowers:brainstorming not triggered"
  PASS=false
fi

echo ""
echo "Test 2: pinky-swear:api-spec-brainstorming fires in the same session..."
if grep -q '"name":"Skill"' "$OUTPUT_FILE" && grep -qE '"skill":"([^"]*:)?api-spec-brainstorming"' "$OUTPUT_FILE"; then
  echo "  [PASS] pinky-swear:api-spec-brainstorming triggered"
else
  echo "  [FAIL] pinky-swear:api-spec-brainstorming NOT triggered"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$OUTPUT_FILE" 2>/dev/null | sort -u || echo "  (none)"

rm -f "$OUTPUT_FILE"

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All brainstorming trigger tests passed ==="
  exit 0
else
  echo "=== Brainstorming trigger tests FAILED ==="
  exit 1
fi

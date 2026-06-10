#!/usr/bin/env bash
# Test: api-mcp-server triggers on MCP generation phrases, NOT brainstorming
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: mcp-server triggers ==="
echo ""

run_mcp_trigger_test() {
  local label="$1"
  local prompt="$2"
  local output_file
  output_file=$(mktemp)

  API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
  claude -p "$prompt" \
    --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns 3 \
    --output-format stream-json \
    > "$output_file" 2>&1 || true

  local pass=true

  if grep -q '"name":"Skill"' "$output_file" && grep -qE '"skill":"([^"]*:)?api-mcp-server"' "$output_file"; then
    echo "  [PASS] pinky-promise:api-mcp-server triggered"
  else
    echo "  [FAIL] pinky-promise:api-mcp-server NOT triggered ($label)"
    pass=false
  fi

  if grep -qE '"skill":"([^"]*:)?brainstorming"' "$output_file"; then
    echo "  [FAIL] superpowers:brainstorming was triggered (should not be)"
    pass=false
  else
    echo "  [PASS] superpowers:brainstorming NOT triggered"
  fi

  echo "  Skills: $(grep -o '"skill":"[^"]*"' "$output_file" 2>/dev/null | sort -u | tr '\n' ' ' || echo '(none)')"
  rm -f "$output_file"
  [ "$pass" = "true" ]
}

PASS=true

echo "Test 1: bare MCP phrase..."
run_mcp_trigger_test "bare" \
  "generate an mcp server" \
  || PASS=false

echo ""
echo "Test 2: service-qualified phrase..."
run_mcp_trigger_test "service" \
  "generate an mcp server for this service" \
  || PASS=false

echo ""
echo "Test 3: spec-qualified phrase..."
run_mcp_trigger_test "spec" \
  "generate an mcp server from the specs" \
  || PASS=false

echo ""
echo "Test 4: user's exact failing phrase..."
run_mcp_trigger_test "exact" \
  "generate an mcp server for this" \
  || PASS=false

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All mcp-server trigger tests passed ==="
  exit 0
else
  echo "=== mcp-server trigger tests FAILED ==="
  exit 1
fi

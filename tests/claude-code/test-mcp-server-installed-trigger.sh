#!/usr/bin/env bash
# Test: api-mcp-server triggers in an INSTALLED context (no project CLAUDE.md)
#
# The existing trigger tests use --plugin-dir from the promise repo, which means
# the promise repo's own CLAUDE.md becomes the PROJECT CLAUDE.md (highest priority).
# That's why those tests pass — the MCP hook is in the project CLAUDE.md.
#
# In a real installed session (e.g. repo-stats-mcp), the plugin's CLAUDE.md is
# only loaded as supplementary plugin context. The model fires superpowers:brainstorming
# BEFORE the plugin CLAUDE.md override is consulted.
#
# This test reproduces that real scenario: claude runs from a temp directory with NO
# project CLAUDE.md, but with --plugin-dir loading the plugin. The plugin CLAUDE.md
# is therefore only a plugin, not the project CLAUDE.md. If the trigger relies solely
# on the plugin CLAUDE.md (not the skill frontmatter description), it will fail here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: mcp-server triggers in installed context (no project CLAUDE.md) ==="
echo ""

run_installed_trigger_test() {
  local label="$1"
  local prompt="$2"
  local output_file
  output_file=$(mktemp)

  # Run from a fresh temp dir with no project CLAUDE.md
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
  claude -p "$prompt" \
    --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns 3 \
    --output-format stream-json \
    2>&1 \
    | (cd "$tmpdir" && cat) \
    > "$output_file" \
    || true

  # Re-run directly in tmpdir (simulates: no project CLAUDE.md, plugin loaded externally)
  rm -f "$output_file"
  output_file=$(mktemp)

  (cd "$tmpdir" && \
    API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
    claude -p "$prompt" \
      --verbose \
      --plugin-dir "$PLUGIN_DIR" \
      --dangerously-skip-permissions \
      --max-turns 3 \
      --output-format stream-json \
    > "$output_file" 2>&1 || true
  )

  rm -rf "$tmpdir"
  trap - EXIT

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

echo "Test 1: exact user phrase in installed context..."
run_installed_trigger_test "installed-exact" \
  "generate an mcp server for this" \
  || PASS=false

echo ""
echo "Test 2: bare phrase in installed context..."
run_installed_trigger_test "installed-bare" \
  "generate an mcp server" \
  || PASS=false

echo ""
echo "Test 3: service-qualified phrase in installed context..."
run_installed_trigger_test "installed-service" \
  "generate an mcp server for this service" \
  || PASS=false

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All installed-context trigger tests passed ==="
  exit 0
else
  echo "=== installed-context trigger tests FAILED ==="
  exit 1
fi

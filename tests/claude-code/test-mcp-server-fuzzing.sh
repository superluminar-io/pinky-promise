#!/usr/bin/env bash
# Fuzzing test: a wide range of prompts that should trigger api-mcp-server
# Tests run in installed context (temp dir, no project CLAUDE.md) to simulate
# the real user scenario. Each test verifies:
#   - api-mcp-server fires
#   - superpowers:brainstorming does NOT fire
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: mcp-server fuzzing (installed context) ==="
echo ""

run_fuzz_test() {
  local label="$1"
  local prompt="$2"
  local output_file
  output_file=$(mktemp)

  local tmpdir
  tmpdir=$(mktemp -d)

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

  local pass=true

  if grep -q '"name":"Skill"' "$output_file" && grep -qE '"skill":"([^"]*:)?api-mcp-server"' "$output_file"; then
    echo "  [PASS] $label"
  else
    local skills
    skills=$(grep -o '"skill":"[^"]*"' "$output_file" 2>/dev/null | sort -u | tr '\n' ' ' || echo "(none)")
    echo "  [FAIL] $label — skills: $skills"
    pass=false
  fi

  if grep -qE '"skill":"([^"]*:)?brainstorming"' "$output_file"; then
    echo "  [FAIL] $label — brainstorming fired (should not)"
    pass=false
  fi

  rm -f "$output_file"
  [ "$pass" = "true" ]
}

PASS=true
FAILED=()

# Explicit MCP keyword prompts
echo "--- explicit mcp keyword ---"
run_fuzz_test "generate an mcp server" \
  "generate an mcp server" || { PASS=false; FAILED+=("generate an mcp server"); }

run_fuzz_test "create mcp tools for this api" \
  "create mcp tools for this api" || { PASS=false; FAILED+=("create mcp tools for this api"); }

run_fuzz_test "expose this service as mcp tools" \
  "expose this service as mcp tools" || { PASS=false; FAILED+=("expose this service as mcp tools"); }

run_fuzz_test "wrap this api for use with mcp" \
  "wrap this api for use with mcp" || { PASS=false; FAILED+=("wrap this api for use with mcp"); }

run_fuzz_test "add mcp support to this service" \
  "add mcp support to this service" || { PASS=false; FAILED+=("add mcp support to this service"); }

run_fuzz_test "build an mcp integration for this" \
  "build an mcp integration for this" || { PASS=false; FAILED+=("build an mcp integration for this"); }

run_fuzz_test "generate mcp tooling for this" \
  "generate mcp tooling for this" || { PASS=false; FAILED+=("generate mcp tooling for this"); }

echo ""
echo "--- intent-based (no mcp keyword) ---"

run_fuzz_test "i want claude to be able to call this" \
  "i want claude to be able to call this" || { PASS=false; FAILED+=("i want claude to be able to call this"); }

run_fuzz_test "make this callable from claude" \
  "make this callable from claude" || { PASS=false; FAILED+=("make this callable from claude"); }

run_fuzz_test "i want to use this in my strands app" \
  "i want to use this in my strands app" || { PASS=false; FAILED+=("i want to use this in my strands app"); }

run_fuzz_test "i want to use this service in my ai agent" \
  "i want to use this service in my ai agent" || { PASS=false; FAILED+=("i want to use this service in my ai agent"); }

run_fuzz_test "i want to connect this to my claude workflow" \
  "i want to connect this to my claude workflow" || { PASS=false; FAILED+=("i want to connect this to my claude workflow"); }

run_fuzz_test "make this service available as ai tools" \
  "make this service available as ai tools" || { PASS=false; FAILED+=("make this service available as ai tools"); }

run_fuzz_test "expose the api as tools for an llm" \
  "expose the api as tools for an llm" || { PASS=false; FAILED+=("expose the api as tools for an llm"); }

run_fuzz_test "i want an agent to be able to use this service" \
  "i want an agent to be able to use this service" || { PASS=false; FAILED+=("i want an agent to be able to use this service"); }

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All fuzzing tests passed ==="
  exit 0
else
  echo "=== Fuzzing tests FAILED ==="
  echo "Failed prompts:"
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

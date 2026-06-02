#!/usr/bin/env bash
# Shared helpers for pinky-swear fast qualitative tests.
# Source this file; do not run it directly.

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$HELPERS_DIR/../.." && pwd)"

# Run Claude with a question and return the plain-text response.
# Usage: run_claude "question" [max_turns]
run_claude() {
  local prompt="$1"
  local max_turns="${2:-2}"
  local output_file
  output_file=$(mktemp)

  API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
  claude -p "$prompt" \
    --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns "$max_turns" \
    --output-format stream-json \
    > "$output_file" 2>&1 || true

  grep '"type":"result"' "$output_file" | head -1 \
    | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result',''))" 2>/dev/null \
    || echo ""

  rm -f "$output_file"
}

# Assert output matches a pattern (case-insensitive extended regex).
# Usage: assert_contains "$output" "pattern" "test name"
assert_contains() {
  local output="$1"
  local pattern="$2"
  local name="${3:-test}"

  if echo "$output" | grep -qiE "$pattern"; then
    echo "  [PASS] $name"
    return 0
  else
    echo "  [FAIL] $name"
    echo "         expected pattern: $pattern"
    echo "         in output: $(echo "$output" | head -3 | sed 's/^/         /')"
    return 1
  fi
}

# Assert output does NOT match a pattern (case-insensitive extended regex).
# Usage: assert_not_contains "$output" "pattern" "test name"
assert_not_contains() {
  local output="$1"
  local pattern="$2"
  local name="${3:-test}"

  if echo "$output" | grep -qiE "$pattern"; then
    echo "  [FAIL] $name"
    echo "         unexpected pattern found: $pattern"
    return 1
  else
    echo "  [PASS] $name"
    return 0
  fi
}

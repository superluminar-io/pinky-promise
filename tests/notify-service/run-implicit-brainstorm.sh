#!/usr/bin/env bash
# Test: pinky-promise:api-spec-brainstorming fires without being explicitly requested.
#
# The prompt describes a service design naturally — no mention of pinky-promise,
# no instruction to invoke any skill. Asserts that Claude discovers on its own
# that api-spec-brainstorming is applicable and invokes it.
#
# Usage: ./run-implicit-brainstorm.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/implicit-brainstorm.txt"
MAX_TURNS=5
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/implicit-brainstorm"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: implicit api-spec-brainstorming trigger ==="
echo "Plugin dir: $PLUGIN_DIR"
echo ""

cd "$OUTPUT_DIR"
API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
claude -p "$PROMPT" \
  --verbose \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --max-turns "$MAX_TURNS" \
  --output-format stream-json \
  > "$LOG_FILE" 2>&1 || true

echo "=== Results ==="

PASS=true

SKILL_PATTERN='"skill":"([^"]*:)?api-spec-brainstorming"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "PASS: api-spec-brainstorming triggered without explicit instruction"
else
  echo "FAIL: api-spec-brainstorming was NOT triggered"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "Session result:"
  grep '"type":"result"' "$LOG_FILE" | head -1 \
    | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','')[:600])" 2>/dev/null || echo "  (could not extract)"
fi

echo ""
echo "Full log: $LOG_FILE"

if [ "$PASS" = "true" ]; then
  echo "All tests passed."
  exit 0
else
  echo "Tests FAILED."
  exit 1
fi

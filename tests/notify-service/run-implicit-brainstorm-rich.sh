#!/usr/bin/env bash
# Test: api-spec-brainstorming fires on a rich, opinionated brainstorm prompt.
#
# Reproduces the case where a user gives a detailed service description with
# tech choices (Go, serverless, AWS) and no mention of pinky-promise. Asserts
# that Claude still recognises api-spec-brainstorming is applicable and invokes
# it alongside superpowers:brainstorming.
#
# This test is currently FAILING — it is added to track the known gap and
# automatically go green when the fix lands.
#
# Usage: ./run-implicit-brainstorm-rich.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/implicit-brainstorm-rich.txt"
MAX_TURNS=5
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/implicit-brainstorm-rich"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: implicit api-spec-brainstorming (rich prompt) ==="
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
  echo "PASS: api-spec-brainstorming triggered on rich prompt"
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

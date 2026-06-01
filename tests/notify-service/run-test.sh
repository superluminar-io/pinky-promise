#!/usr/bin/env bash
# Test: notify-service brainstorming triggers api-spec-brainstorming
#
# Verifies that starting a brainstorm for a service with no published spec
# causes pinky-swear to invoke the api-spec-brainstorming skill.
#
# Usage: ./run-test.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/initial-brainstorm.txt"
MAX_TURNS=3
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/notify-service"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: notify-service brainstorming ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Output dir: $OUTPUT_DIR"
echo ""

cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

# Run Claude headlessly with pinky-swear loaded.
# API_REGISTRY_REPO must be set (any value) — without it, pinky-swear skips all
# skill invocations silently per its CLAUDE.md configuration guard.
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

# Assert api-spec-brainstorming was invoked.
# Match bare name or namespace-prefixed form (e.g. pinky-swear:api-spec-brainstorming).
SKILL_PATTERN='"skill":"([^"]*:)?api-spec-brainstorming"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "PASS: api-spec-brainstorming was triggered"
else
  echo "FAIL: api-spec-brainstorming was NOT triggered"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "First assistant response:"
  grep '"type":"assistant"' "$LOG_FILE" | head -1 \
    | jq -r '.message.content[0].text // .message.content' 2>/dev/null | head -c 800 \
    || echo "  (could not extract)"
fi

echo ""
echo "Full log: $LOG_FILE"

if [ "$PASS" = "true" ]; then
  echo ""
  echo "All tests passed."
  exit 0
else
  echo ""
  echo "Tests FAILED."
  exit 1
fi

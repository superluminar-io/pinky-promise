#!/usr/bin/env bash
# Sanity check: verify pinky-promise plugin loads and its CLAUDE.md is visible.
# Run this before the scenario tests to confirm the plugin wiring is correct.
#
# Usage: ./tests/check-plugin-loaded.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/notify-service/prompts/plugin-loaded.txt"
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/check-plugin-loaded"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Check: plugin loads correctly ==="
echo "Plugin dir: $PLUGIN_DIR"
echo ""

claude -p "$PROMPT" \
  --verbose \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --max-turns 1 \
  --output-format stream-json \
  > "$LOG_FILE" 2>&1 || true

echo "=== Results ==="

# Extract final result text (stream-json puts the full response in "type":"result")
RESPONSE=$(grep '"type":"result"' "$LOG_FILE" | head -1 \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result',''))" 2>/dev/null || echo "")

if [ -z "$RESPONSE" ]; then
  echo "FAIL: no assistant response — plugin may have failed to load"
  echo ""
  echo "Raw log:"
  cat "$LOG_FILE"
  exit 1
fi

# Check that the response mentions pinky-promise or api-spec-brainstorming
if echo "$RESPONSE" | grep -qi "pinky-promise\|api-spec-brainstorming\|api-contract-check\|api-change-guardian\|api-spec-publish"; then
  echo "PASS: plugin is loaded — response references pinky-promise skills"
else
  echo "FAIL: plugin does not appear to be loaded"
  echo ""
  echo "Response:"
  echo "$RESPONSE"
  exit 1
fi

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "Full response:"
  echo "$RESPONSE"
fi

echo ""
echo "Full log: $LOG_FILE"

#!/usr/bin/env bash
# Test: brainstorming a service that calls an external API surfaces import suggestion
#
# Verifies that when a brainstorm mentions calling an unregistered external
# service (Twilio), pinky-swear surfaces the /api-spec-import suggestion.
#
# Usage: ./run-brainstorm-with-external.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/brainstorm-with-external.txt"
MAX_TURNS=10
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/notify-service-external"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: brainstorming with external service dependency ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Output dir: $OUTPUT_DIR"
echo ""

cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

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

RESULT=$(grep '"type":"result"' "$LOG_FILE" | head -1 \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','').lower())" 2>/dev/null || echo "")

# Assert the import suggestion surfaces somewhere in the session output
ALL_TEXT=$(grep '"type":"assistant"' "$LOG_FILE" \
  | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        for c in d.get('message',{}).get('content',[]):
            if c.get('type') == 'text':
                print(c['text'].lower())
    except:
        pass
" 2>/dev/null || echo "")
ALL_TEXT="${ALL_TEXT}${RESULT}"

if echo "$ALL_TEXT" | grep -qE "api-spec-import|no public api entry|no.*registry.*entry.*twilio|twilio.*no.*registry"; then
  echo "PASS: import suggestion surfaced for unregistered external service"
else
  echo "FAIL: import suggestion not observed for Twilio dependency"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "Session result:"
  echo "$RESULT" | head -c 800
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

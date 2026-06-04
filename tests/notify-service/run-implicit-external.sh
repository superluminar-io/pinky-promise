#!/usr/bin/env bash
# Test: import suggestion surfaces without explicit instruction when design mentions
# an unregistered external service.
#
# The prompt mentions Twilio naturally. Asserts pinky-swear surfaces the
# /api-spec-import suggestion on its own.
#
# Usage: ./run-implicit-external.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/implicit-brainstorm-with-external.txt"
MAX_TURNS=5
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/implicit-external"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: implicit external service import suggestion ==="
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

RESULT=$(grep '"type":"result"' "$LOG_FILE" | head -1 \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','').lower())" 2>/dev/null || echo "")

COMBINED="${ALL_TEXT}${RESULT}"

if echo "$COMBINED" | grep -qE "api-spec-import|no public api entry|no.*registry.*entry"; then
  echo "PASS: import suggestion surfaced without explicit instruction"
else
  echo "FAIL: import suggestion not observed"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "Session result:"
  echo "$RESULT" | head -c 600
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

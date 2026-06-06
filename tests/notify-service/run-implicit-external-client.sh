#!/usr/bin/env bash
# Test: import suggestion fires when building a client for an external API.
#
# The user is building a GitHub client, not a service. pinky-promise must
# still surface /api-spec-import for GitHub even though no service API is
# being designed. This tests the standalone external service check in CLAUDE.md
# which should fire independently of api-spec-brainstorming.
#
# Usage: ./run-implicit-external-client.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/implicit-external-client.txt"
MAX_TURNS=10
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/implicit-external-client"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: import suggestion for external API client (no service being designed) ==="
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

if echo "$COMBINED" | grep -qE "api-spec-import|no public api entry|no.*registry.*entry|register.*github"; then
  echo "PASS: import suggestion surfaced for GitHub API"
else
  echo "FAIL: import suggestion not observed for GitHub API client"
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

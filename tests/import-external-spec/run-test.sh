#!/usr/bin/env bash
# Test: /api-spec-import triggers api-spec-import skill
#
# Verifies that the api-spec-import slash command causes pinky-swear to
# invoke the api-spec-import skill.
#
# Usage: ./run-test.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/import-openapi.txt"
MAX_TURNS=5
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/import-external-spec"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: api-spec-import skill triggering ==="
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

SKILL_PATTERN='"skill":"([^"]*:)?api-spec-import"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "PASS: api-spec-import was triggered"
else
  echo "FAIL: api-spec-import was NOT triggered"
  PASS=false
fi

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "First assistant response:"
  grep '"type":"result"' "$LOG_FILE" | head -1 \
    | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','')[:800])" 2>/dev/null \
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

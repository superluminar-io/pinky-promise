#!/usr/bin/env bash
# Test: api-contract-check surfaces violations against a published spec.
#
# Seeds a local bare registry with user-service/1.0.0.json, pre-creates
# api-dependencies.json pinning user-service@1.0.0, then runs a session
# reviewing code that calls a non-existent operation. Asserts the skill
# was invoked and reported a violation.
#
# Usage: ./run-test.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$PLUGIN_DIR/tests/fixtures"
PROMPT_FILE="$SCRIPT_DIR/prompts/consumer-review.txt"
MAX_TURNS=10
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

source "$PLUGIN_DIR/tests/registry-helpers.sh"

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/api-contract-check"
mkdir -p "$OUTPUT_DIR"

REGISTRY=$(create_bare_registry)
seed_registry_spec "$REGISTRY" "$FIXTURES_DIR/user-service-1.0.0.json" "$FIXTURES_DIR/user-service-bindings.json"

# Pre-create api-dependencies.json so the skill skips the interactive setup step
echo '{"user-service": "1.0.0"}' > "$OUTPUT_DIR/api-dependencies.json"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: api-contract-check integration ==="
echo "Plugin dir:  $PLUGIN_DIR"
echo "Registry:    $REGISTRY"
echo "Output dir:  $OUTPUT_DIR"
echo ""

cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

cd "$OUTPUT_DIR"
API_REGISTRY_REPO="$REGISTRY" \
claude -p "$PROMPT" \
  --verbose \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --max-turns "$MAX_TURNS" \
  --output-format stream-json \
  > "$LOG_FILE" 2>&1 || true

rm -rf "$REGISTRY"

echo "=== Results ==="

PASS=true

SKILL_PATTERN='"skill":"([^"]*:)?api-contract-check"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "PASS: api-contract-check was invoked"
else
  echo "FAIL: api-contract-check was NOT invoked"
  PASS=false
fi

RESULT=$(grep '"type":"result"' "$LOG_FILE" | head -1 \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','').lower())" 2>/dev/null || echo "")

if echo "$RESULT" | grep -qiE "getUserByEmail|violation|not.*exist|not.*found|does not exist"; then
  echo "PASS: contract violation for non-existent operation surfaced"
else
  echo "FAIL: violation for getUserByEmail not observed in result"
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

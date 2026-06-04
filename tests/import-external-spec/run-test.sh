#!/usr/bin/env bash
# Test: /api-spec-import executes the api-spec-import skill behaviour
#
# Slash command skills run their content directly rather than via the Skill
# tool, so this test asserts on behavioural evidence: Claude fetches the spec,
# detects the format, and derives a service name — the first observable steps
# of the skill's execution flow.
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
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/import-external-spec"
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

# Slash command skills execute their content directly — the Skill tool is not
# invoked. Assert on behavioural evidence: the result must show both service
# name derivation and version detection, proving the skill executed past
# fetch+detect into derivation (step 5).
RESULT=$(grep '"type":"result"' "$LOG_FILE" | head -1 \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('result','').lower())" 2>/dev/null || echo "")

# Require evidence of both step 5 (service name derivation) and step 5's
# version field — proving the skill executed past fetch+detect into derivation.
if echo "$RESULT" | grep -qE "(service name|derived service name|swagger-petstore|petstore)" && \
   echo "$RESULT" | grep -qE "(external version|version.*1\.[0-9]|1\.0\.[0-9]+)"; then
  echo "PASS: api-spec-import executed (service name and version derivation observed)"
else
  echo "FAIL: api-spec-import skill steps not observed in response (expected service name + version derivation)"
  PASS=false
fi

echo ""
echo "Skills triggered via Skill tool:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none — expected for slash command skills)"

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

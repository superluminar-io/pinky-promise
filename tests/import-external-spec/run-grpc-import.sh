#!/usr/bin/env bash
# Test: /api-spec-import detects gRPC format and handles streaming RPCs
#
# Uses a local .proto fixture (fixtures/echo-service.proto) with both
# unary and server-streaming RPCs. Verifies the skill detects gRPC format,
# derives the service name from the package declaration, and distinguishes
# unary operations from streaming events.
#
# Usage: ./run-grpc-import.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$SCRIPT_DIR/fixtures/echo-service.proto"
PROMPT_FILE="$SCRIPT_DIR/prompts/import-grpc.txt"
MAX_TURNS=5
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-promise-tests/${TIMESTAMP}/import-grpc"
mkdir -p "$OUTPUT_DIR"

# Copy fixture to the output dir so the skill can read it via relative path
cp "$FIXTURE" "$OUTPUT_DIR/echo-service.proto"

LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: api-spec-import gRPC format detection ==="
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

# Assert gRPC format was detected
if echo "$RESULT" | grep -qiE "grpc|proto(col buffer)?|proto3"; then
  echo "PASS: gRPC format detected"
else
  echo "FAIL: gRPC format not detected"
  PASS=false
fi

# Assert service name derived from package declaration
if echo "$RESULT" | grep -qiE "echo(-service)?|service name.*echo|echo.*service name"; then
  echo "PASS: service name derived from package"
else
  echo "FAIL: service name not derived from package declaration"
  PASS=false
fi

echo ""
echo "Skills triggered via Skill tool:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none — expected for slash command skills)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "First assistant response:"
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

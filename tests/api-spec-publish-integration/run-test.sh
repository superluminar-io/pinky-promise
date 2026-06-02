#!/usr/bin/env bash
# Test: api-spec-publish commits and pushes a draft spec to a local bare registry.
#
# Uses a bare git repo in /tmp as the registry — no remote access needed.
# Asserts the spec file appears in the registry after the session.
#
# Usage: ./run-test.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/publish-draft.txt"
MAX_TURNS=10
VERBOSE=false

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
  esac
done

source "$PLUGIN_DIR/tests/registry-helpers.sh"

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/pinky-swear-tests/${TIMESTAMP}/api-spec-publish"
mkdir -p "$OUTPUT_DIR"

REGISTRY=$(create_bare_registry)
LOG_FILE="$OUTPUT_DIR/claude-output.json"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Test: api-spec-publish integration ==="
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

echo "=== Results ==="

PASS=true

# Verify the spec was actually pushed into the bare registry
VERIFY=$(mktemp -d)
git clone "$REGISTRY" "$VERIFY" -q 2>/dev/null || true

if [[ -f "$VERIFY/services/user-service/1.0.0.json" ]]; then
  echo "PASS: services/user-service/1.0.0.json exists in registry"
else
  echo "FAIL: contract not found in registry after publish"
  echo "      Registry contents:"
  find "$VERIFY" -type f | sed 's/^/        /' || true
  PASS=false
fi

if [[ -f "$VERIFY/services/user-service/bindings.json" ]]; then
  echo "PASS: services/user-service/bindings.json exists in registry"
else
  echo "FAIL: bindings.json not found in registry after publish"
  PASS=false
fi

rm -rf "$VERIFY" "$REGISTRY"

echo ""
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

if [ "$VERBOSE" = "true" ]; then
  echo ""
  echo "Session result:"
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

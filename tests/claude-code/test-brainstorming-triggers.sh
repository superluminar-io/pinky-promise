#!/usr/bin/env bash
# Test: api-spec-brainstorming fires alongside superpowers:brainstorming
#
# Uses --plugin-dir to load the plugin, then checks that a brainstorm
# prompt triggers BOTH superpowers:brainstorming AND
# pinky-swear:api-spec-brainstorming in the same response.
#
# Note: --plugin-dir bypasses the system-reminder skill-discovery path, so
# these tests cannot validate whether the skill description alone is sufficient
# to trigger co-invocation in an installed session. They verify the skill
# fires correctly once available, including on rich prompts with tech context.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: brainstorming trigger ==="
echo ""

run_brainstorm_test() {
  local label="$1"
  local prompt="$2"
  local output_file
  output_file=$(mktemp)

  API_REGISTRY_REPO="${API_REGISTRY_REPO:-git@github.com:test/api-registry.git}" \
  claude -p "$prompt" \
    --verbose \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns 3 \
    --output-format stream-json \
    > "$output_file" 2>&1 || true

  local pass=true

  if grep -qE '"skill":"([^"]*:)?brainstorming"' "$output_file"; then
    echo "  [PASS] superpowers:brainstorming triggered"
  else
    echo "  [FAIL] superpowers:brainstorming not triggered"
    pass=false
  fi

  if grep -q '"name":"Skill"' "$output_file" && grep -qE '"skill":"([^"]*:)?api-spec-brainstorming"' "$output_file"; then
    echo "  [PASS] pinky-swear:api-spec-brainstorming triggered"
  else
    echo "  [FAIL] pinky-swear:api-spec-brainstorming NOT triggered ($label)"
    pass=false
  fi

  echo "  Skills: $(grep -o '"skill":"[^"]*"' "$output_file" 2>/dev/null | sort -u | tr '\n' ' ' || echo '(none)')"
  rm -f "$output_file"
  [ "$pass" = "true" ]
}

PASS=true

echo "Test 1: simple brainstorm prompt..."
run_brainstorm_test "simple" \
  "I want to build a url-shortener service. It shall shorten URLs, resolve short codes, and send a notification when a URL expires. Let's brainstorm." \
  || PASS=false

echo ""
echo "Test 2: rich prompt with tech choices (Go, AWS, serverless)..."
run_brainstorm_test "rich" \
  "I want to build a public url shortener service. It shall shorten urls, resolve short codes and send a notification via a hard-coded webhook when a url expires. It shall run serverless with an on demand billing model on AWS. Build it in Go. Expire all urls after about 30 days. Setup a CDK project in Go as well. Use basic auth with username:password for authorization." \
  || PASS=false

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All brainstorming trigger tests passed ==="
  exit 0
else
  echo "=== Brainstorming trigger tests FAILED ==="
  exit 1
fi

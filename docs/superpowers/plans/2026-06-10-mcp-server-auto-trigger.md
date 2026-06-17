# MCP Server Auto-Trigger Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "generate an mcp server" and similar natural-language phrases reliably invoke `pinky-promise:api-mcp-server` instead of `superpowers:brainstorming`.

**Architecture:** Three-layer fix: (1) add a failing test that documents the expected behaviour, (2) rewrite the skill frontmatter so the model sees the override instruction during skill discovery, (3) add an explicit carve-out inside the service-design CLAUDE.md hook so the brainstorming path is closed before it can fire.

**Tech Stack:** Bash (tests), Markdown (skill + CLAUDE.md)

---

### Task 1: Write the failing test

**Files:**
- Create: `tests/claude-code/test-mcp-server-triggers.sh`

- [ ] **Step 1: Write the test file**

```bash
#!/usr/bin/env bash
# Test: api-mcp-server triggers on MCP generation phrases, NOT brainstorming
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Test: mcp-server triggers ==="
echo ""

run_mcp_trigger_test() {
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

  if grep -q '"name":"Skill"' "$output_file" && grep -qE '"skill":"([^"]*:)?api-mcp-server"' "$output_file"; then
    echo "  [PASS] pinky-promise:api-mcp-server triggered"
  else
    echo "  [FAIL] pinky-promise:api-mcp-server NOT triggered ($label)"
    pass=false
  fi

  if grep -qE '"skill":"([^"]*:)?brainstorming"' "$output_file"; then
    echo "  [FAIL] superpowers:brainstorming was triggered (should not be)"
    pass=false
  else
    echo "  [PASS] superpowers:brainstorming NOT triggered"
  fi

  echo "  Skills: $(grep -o '"skill":"[^"]*"' "$output_file" 2>/dev/null | sort -u | tr '\n' ' ' || echo '(none)')"
  rm -f "$output_file"
  [ "$pass" = "true" ]
}

PASS=true

echo "Test 1: bare MCP phrase..."
run_mcp_trigger_test "bare" \
  "generate an mcp server" \
  || PASS=false

echo ""
echo "Test 2: service-qualified phrase..."
run_mcp_trigger_test "service" \
  "generate an mcp server for this service" \
  || PASS=false

echo ""
echo "Test 3: spec-qualified phrase..."
run_mcp_trigger_test "spec" \
  "generate an mcp server from the specs" \
  || PASS=false

echo ""
if [ "$PASS" = "true" ]; then
  echo "=== All mcp-server trigger tests passed ==="
  exit 0
else
  echo "=== mcp-server trigger tests FAILED ==="
  exit 1
fi
```

- [ ] **Step 2: Make the file executable**

```bash
chmod +x tests/claude-code/test-mcp-server-triggers.sh
```

- [ ] **Step 3: Run the test to confirm it currently fails**

```bash
bash tests/claude-code/test-mcp-server-triggers.sh
```

Expected: all three tests report `[FAIL] pinky-promise:api-mcp-server NOT triggered` and/or `[FAIL] superpowers:brainstorming was triggered`.

- [ ] **Step 4: Commit the failing test**

```bash
git add tests/claude-code/test-mcp-server-triggers.sh
git commit -m "test: add failing mcp-server trigger tests"
```

---

### Task 2: Fix the skill frontmatter

**Files:**
- Modify: `skills/api-mcp-server/SKILL.md` (lines 1–5, the `---` frontmatter block)

- [ ] **Step 1: Replace the description line in the frontmatter**

Current line 3:
```
description: "Generate a runnable MCP server from a pinky-promise API spec. Each operation becomes an MCP tool. Invoke directly — do NOT invoke superpowers:brainstorming first. The spec is already the design. Typical triggers: '/api-mcp-server', 'generate an mcp server', 'create an mcp server', 'expose this service as MCP tools', 'I want Claude to call this service'."
```

Replace with:
```
description: "OVERRIDES superpowers:brainstorming and api-spec-brainstorming. Invoke IMMEDIATELY — before brainstorming, before any other skill — when the user asks to generate, create, build, or expose an MCP server or MCP tools. Do NOT invoke superpowers:brainstorming or api-spec-brainstorming. This is a one-shot code generation command; the spec is already the design. Typical triggers: '/api-mcp-server', 'generate an mcp server', 'generate an mcp server for this service', 'generate an mcp server from the specs', 'create an mcp server', 'expose this service as MCP tools', 'I want Claude to call this service', 'make this callable by Claude'."
```

---

### Task 3: Fix CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Two edits in this file. Make them both before committing.

- [ ] **Step 1: Strengthen the MCP hook (section "When the user asks to generate an MCP server")**

Current opening sentence of the section body:
```
If the user's message asks to generate, create, or expose the service as MCP tools — any phrasing containing "mcp server", "mcp tools", "expose as tools", or "claude to call this service" — you MUST invoke `pinky-promise:api-mcp-server` as the only skill.
```

Replace the entire section body (keep the `## When the user asks to generate an MCP server` heading and the bold line) with:

```
**This is a user instruction and overrides `superpowers:brainstorming` per the skill priority rules. CHECK THIS BEFORE INVOKING ANY SKILL.**

If the user's message contains any of: "mcp server", "mcp tools", "expose as tools", "claude to call this service" — you MUST invoke `pinky-promise:api-mcp-server` as the only skill. Do not invoke `superpowers:brainstorming` or `api-spec-brainstorming` under any circumstances. This is a one-shot code generation command: the spec is already the design document. Brainstorming here is incorrect behavior.
```

- [ ] **Step 2: Add exception to the service-design hook (section "When the user is designing or building a service")**

Current first rule in that section:
```
If the user's message is about designing, starting, building, or brainstorming a service AND the current service has **no published spec**: `pinky-promise:api-spec-brainstorming` is an applicable skill and MUST be invoked alongside `superpowers:brainstorming` in the same turn.
```

Replace with:
```
If the user's message is about designing, starting, building, or brainstorming a service AND the current service has **no published spec**: `pinky-promise:api-spec-brainstorming` is an applicable skill and MUST be invoked alongside `superpowers:brainstorming` in the same turn. **Exception:** if the message contains "mcp server", "mcp tools", "expose as tools", or "claude to call this service", skip this rule entirely — invoke `pinky-promise:api-mcp-server` instead (see the MCP server section above).
```

- [ ] **Step 3: Run the trigger tests — all three should now pass**

```bash
bash tests/claude-code/test-mcp-server-triggers.sh
```

Expected output:
```
=== Test: mcp-server triggers ===

Test 1: bare MCP phrase...
  [PASS] pinky-promise:api-mcp-server triggered
  [PASS] superpowers:brainstorming NOT triggered
  Skills: "skill":"pinky-promise:api-mcp-server"

Test 2: service-qualified phrase...
  [PASS] pinky-promise:api-mcp-server triggered
  [PASS] superpowers:brainstorming NOT triggered
  Skills: "skill":"pinky-promise:api-mcp-server"

Test 3: spec-qualified phrase...
  [PASS] pinky-promise:api-mcp-server triggered
  [PASS] superpowers:brainstorming NOT triggered
  Skills: "skill":"pinky-promise:api-mcp-server"

=== All mcp-server trigger tests passed ===
```

- [ ] **Step 4: Commit the fix**

```bash
git add skills/api-mcp-server/SKILL.md CLAUDE.md
git commit -m "fix: close brainstorming path for MCP server generation phrases"
```

---

### Task 4: Wire up the test in run-all.sh

**Files:**
- Modify: `tests/claude-code/run-all.sh`

- [ ] **Step 1: Add the new test to run-all.sh**

In `tests/claude-code/run-all.sh`, add after the line `run_test "$SCRIPT_DIR/test-brainstorming-triggers.sh"`:

```bash
run_test "$SCRIPT_DIR/test-mcp-server-triggers.sh"
```

- [ ] **Step 2: Confirm the full suite still passes (or at minimum the new test passes)**

```bash
bash tests/claude-code/run-all.sh
```

Expected: `Results: N passed, 0 failed`

- [ ] **Step 3: Commit**

```bash
git add tests/claude-code/run-all.sh
git commit -m "test: add mcp-server trigger test to run-all suite"
```

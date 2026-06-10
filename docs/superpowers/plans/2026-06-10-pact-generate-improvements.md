# api-pact-generate Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `api-pact-generate` with role auto-detection, a provider self-validation pattern, anti-hallucination framing, and correct "validation" terminology.

**Architecture:** All changes are targeted edits to `skills/api-pact-generate/SKILL.md`. Tests are qualitative Claude CLI invocations following the established pattern in `tests/claude-code/`.

**Tech Stack:** Bash test harness, `claude` CLI with `--plugin-dir`, stream-json output parsing.

---

## File map

- **Modify:** `skills/api-pact-generate/SKILL.md` — the only skill file; all four changes land here
- **Create:** `tests/claude-code/test-api-pact-generate.sh` — new qualitative test suite for this skill
- **Modify:** `tests/claude-code/run-all.sh` — add the new test to the suite
- **Modify:** `package.json` — bump `0.0.1` → `0.0.2`
- **Modify:** `.claude-plugin/plugin.json` — bump `0.0.1` → `0.0.2`
- **Modify:** `.claude-plugin/marketplace.json` — bump `0.0.1` → `0.0.2`

---

## Task 1: Create the test file with all failing tests

Write the full test file before touching the skill. Every test should fail against the current skill.

**Files:**
- Create: `tests/claude-code/test-api-pact-generate.sh`

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bash
# Test: api-pact-generate skill behaviour
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: api-pact-generate ==="
echo ""

# ── Role detection ────────────────────────────────────────────────────────────

echo "Test 1: Consumer-only project (imported spec, no draft-spec) → auto-detects, no question..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`.pinky-promise/bedrock-runtime-openapi.json\` exists but there is no \`.pinky-promise/draft-spec.json\`, does it ask the user their role or auto-detect it as consumer?")

assert_contains "$output" "auto.detect|no.*question|consumer.*only|detected.*consumer|without asking" \
  "Auto-detects consumer when only imported specs present" || exit 1

echo ""
echo "Test 2: Provider-only project (draft-spec, no imports) → auto-detects, no question..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`.pinky-promise/draft-spec.json\` exists but there are no imported specs and no api-dependencies.json, does it ask the user their role or auto-detect it as provider?")

assert_contains "$output" "auto.detect|no.*question|provider.*only|detected.*provider|without asking" \
  "Auto-detects provider when only draft-spec present" || exit 1

echo ""
echo "Test 3: Both signals → asks with multi-select and clarifying message..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if both \`.pinky-promise/draft-spec.json\` AND \`.pinky-promise/github-openapi.json\` exist, what does it ask the user, and is it single-select or multi-select?")

assert_contains "$output" "multi.select|multiple.*select|select.*multiple|both.*options|check.*box" \
  "Uses multi-select when both signals present" || exit 1
assert_contains "$output" "detected.*both|both.*detected|draft.*spec.*imported|imported.*draft" \
  "Clarifies that both signals were detected" || exit 1

echo ""
echo "Test 4: Neither signal → asks (no auto-detection)..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if there is no draft-spec.json and no imported specs and no api-dependencies.json, does it ask the user their role?")

assert_contains "$output" "ask|prompt|question|role" \
  "Asks when no signals found" || exit 1
assert_not_contains "$output" "auto.detect|without asking|skips.*question" \
  "Does not auto-detect with no signals" || exit 1

echo ""
echo "Test 5: Existing consumer test file → offers update flow, not regenerate..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`pact_consumer_test.go\` already exists in the project, does it offer to update the existing tests or does it regenerate them from scratch?")

assert_contains "$output" "update|review.*existing|existing.*test|propose.*change|delta|one.*by.*one|individually" \
  "Offers update flow when consumer tests already exist" || exit 1
assert_not_contains "$output" "regenerat.*from scratch|overwrite.*immediately|replac.*all" \
  "Does not silently regenerate from scratch" || exit 1

echo ""
echo "Test 6: Existing consumer tests + provider signal → offers both update and add provider..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: if \`pact_consumer_test.go\` already exists AND \`.pinky-promise/draft-spec.json\` also exists, what options does it present to the user?")

assert_contains "$output" "update.*consumer|consumer.*update" \
  "Offers to update existing consumer tests" || exit 1
assert_contains "$output" "add.*provider|provider.*test|generate.*provider" \
  "Offers to add provider tests" || exit 1

# ── Provider self-validation ──────────────────────────────────────────────────

echo ""
echo "Test 7: Provider path → multi-select for both validation patterns..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: when generating provider tests, does it ask the user to choose between self-validation and consumer pact validation as a single-select or multi-select? Can the user pick both?")

assert_contains "$output" "multi.select|multiple.*select|both.*options|select.*both|can.*choose.*both" \
  "Provider pattern selection is multi-select" || exit 1

echo ""
echo "Test 8: Self-validation needs no Pact Broker..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: what is the self-validation pattern and does it require a Pact Broker?")

assert_contains "$output" "no.*broker|without.*broker|broker.*not.*required|no pact broker" \
  "Self-validation requires no Pact Broker" || exit 1
assert_contains "$output" "spec.*contract|spec.*source.*truth|spec.*covers" \
  "Explains why spec is sufficient" || exit 1

# ── Anti-hallucination framing ────────────────────────────────────────────────

echo ""
echo "Test 9: Step 6 announce mentions spec-enforcement guarantee..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: after generating consumer tests, what does the announce say about what happens if client code accesses a field not in the spec?")

assert_contains "$output" "fail|test.*fail|cause.*failure|test.*catch" \
  "Announce explains test failure on non-spec field access" || exit 1
assert_contains "$output" "hallucin|non.spec|not.*in.*spec|only.*spec|spec.*enforc|anti.hallucin" \
  "Announce references anti-hallucination guarantee" || exit 1

echo ""
echo "Test 10: Generated test file includes spec-enforcement comment..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: what comment is added at the top of the generated pact_consumer_test.go file and what is its purpose?")

assert_contains "$output" "comment|explains|purpose" \
  "A comment is added at the top of the generated file" || exit 1
assert_contains "$output" "spec.*contract|contract.*spec|enforce|only.*declared|declared.*spec" \
  "Comment explains spec-enforcement purpose" || exit 1

# ── Terminology ───────────────────────────────────────────────────────────────

echo ""
echo "Test 11: Skill uses 'validation' not 'verification' in user-facing text..."
output=$(run_claude "Invoke the api-pact-generate skill and then answer: when describing the provider test setup, does it use the word 'verification' or 'validation' in the text it shows to the user?")

assert_contains "$output" "validation" \
  "Uses validation in user-facing text" || exit 1
assert_not_contains "$output" "verification" \
  "Does not use verification in user-facing text" || exit 1

echo ""
echo "=== All api-pact-generate tests passed ==="
```

- [ ] **Step 2: Make the file executable**

```bash
chmod +x tests/claude-code/test-api-pact-generate.sh
```

- [ ] **Step 3: Run the tests and confirm they all fail**

```bash
bash tests/claude-code/test-api-pact-generate.sh
```

Expected: multiple `[FAIL]` lines — the current skill has none of these behaviours.

- [ ] **Step 4: Commit the failing tests**

```bash
git checkout -b feat/pact-generate-improvements
git add tests/claude-code/test-api-pact-generate.sh
git commit -m "test: add failing tests for api-pact-generate improvements"
```

---

## Task 2: Implement role detection (Step 1 rewrite)

Replace the unconditional `AskUserQuestion` in Step 1 with filesystem-driven detection.

**Files:**
- Modify: `skills/api-pact-generate/SKILL.md`

- [ ] **Step 1: Replace Step 1 in SKILL.md**

Find and replace the entire `### Step 1: Determine role` section with:

```markdown
### Step 1: Detect role

Check the project state before asking anything:

```bash
ls .pinky-promise/draft-spec.json 2>/dev/null && echo "HAS_DRAFT"
ls .pinky-promise/*.json 2>/dev/null | grep -v draft-spec | head -1 && echo "HAS_IMPORTS"
ls api-dependencies.json 2>/dev/null && echo "HAS_DEPS"
ls pact_consumer_test.go 2>/dev/null && echo "HAS_CONSUMER_TESTS"
ls pact_provider_test.go 2>/dev/null && echo "HAS_PROVIDER_TESTS"
```

**Signals:**
- Provider signal: `HAS_DRAFT`
- Consumer signal: `HAS_IMPORTS` or `HAS_DEPS`
- Existing consumer tests: `HAS_CONSUMER_TESTS`
- Existing provider tests: `HAS_PROVIDER_TESTS`

**Decision table:**

| Existing tests | Role signals | Behaviour |
|---|---|---|
| Consumer only | — | Multi-select: **Update consumer tests** / **Add provider tests** (show "Add provider tests" only if provider signal exists) |
| Provider only | — | Multi-select: **Update provider tests** / **Add consumer tests** (show "Add consumer tests" only if consumer signal exists) |
| Both | — | Multi-select: **Update consumer tests** / **Update provider tests** |
| None | Consumer only | Announce: "Detected consumer-only project — generating consumer tests." → proceed as Consumer |
| None | Provider only | Announce: "Detected provider-only project — generating provider tests." → proceed as Provider |
| None | Both | Ask (multi-select): "pinky-promise detected both a draft spec and imported service dependencies — which would you like to generate?" Options: **Consumer tests** / **Provider tests** |
| None | Neither | Ask (multi-select): "What would you like to generate?" Options: **Consumer tests** / **Provider tests** |

**Update flow** (when updating existing tests): compare the current spec's operations against the operations covered in the existing test file, identified by function name convention (`TestPactConsumer_<OperationName>`, `TestPactProvider_<OperationName>`). For each delta — new operation in spec not yet in tests, changed input/output shape, operation removed from spec — propose the change individually and wait for approval before moving to the next. User can accept, skip, or edit each proposed change.
```

- [ ] **Step 2: Run role detection tests**

```bash
bash tests/claude-code/test-api-pact-generate.sh 2>&1 | grep -E "Test [1-6]|PASS|FAIL"
```

Expected: Tests 1–6 pass, remaining tests still fail.

- [ ] **Step 3: Commit**

```bash
git add skills/api-pact-generate/SKILL.md
git commit -m "feat: auto-detect role in api-pact-generate from project state"
```

---

## Task 3: Implement provider self-validation (Step 7 rewrite)

Replace the single-select Step 7 with a multi-select offering both patterns.

**Files:**
- Modify: `skills/api-pact-generate/SKILL.md`

- [ ] **Step 1: Replace Step 7 in SKILL.md**

Find and replace the entire `### Step 7: Provider verification setup (provider role only)` section with:

```markdown
### Step 7: Provider validation setup (provider role only)

Present a **multi-select** — the user can choose one or both:

- **Self-validation** — generate spec-derived consumer tests to run in this pipeline. No Pact Broker needed. The spec is the complete callable surface; nothing undocumented is reachable by consumers, so these tests cover the full contract boundary.
- **Consumer pact validation** — generate `pact_provider_test.go` to pull and validate consumer-published pacts from a Pact Broker.

**If Self-validation is selected:** run the consumer test generation flow (Steps 3–6) for the provider's own spec. No additional file is generated beyond `pact_consumer_test.go`.

**If Consumer pact validation is selected:** generate `pact_provider_test.go`:

```go
package main_test

import (
    "testing"
    "github.com/pact-foundation/pact-go/v2/provider"
)

func TestPactProvider(t *testing.T) {
    verifier := provider.NewVerifier()
    err := verifier.VerifyProvider(t, provider.VerifyRequest{
        ProviderBaseURL:            "http://localhost:8080",
        BrokerURL:                  "<PACT_BROKER_URL>",
        PublishVerificationResults: true,
        ProviderVersion:            "<version>",
        StateHandlers: provider.StateHandlers{
            // Add state handlers here for each provider state in your pacts
        },
    })
    if err != nil { t.Fatal(err) }
}
```

**If both are selected:** generate `pact_consumer_test.go` first (Steps 3–6), then `pact_provider_test.go`, then announce both run commands together.

Announce (adjust to what was generated):
> "Generated provider validation setup.
>
> Self-validation (no Pact Broker required):
> ```
> go test ./... -run TestPactConsumer
> ```
>
> Consumer pact validation (requires PACT_BROKER_URL):
> ```
> go test ./... -run TestPactProvider
> ```"
```

- [ ] **Step 2: Run provider self-validation tests**

```bash
bash tests/claude-code/test-api-pact-generate.sh 2>&1 | grep -E "Test [7-8]|PASS|FAIL"
```

Expected: Tests 7–8 pass.

- [ ] **Step 3: Commit**

```bash
git add skills/api-pact-generate/SKILL.md
git commit -m "feat: add multi-select provider validation patterns to api-pact-generate"
```

---

## Task 4: Implement anti-hallucination framing (Step 6 additions)

Add the spec-enforcement framing to the Step 6 announce and the generated file comment.

**Files:**
- Modify: `skills/api-pact-generate/SKILL.md`

- [ ] **Step 1: Update the Step 6 generated file template**

Find the `func TestPactConsumer_<OperationName>` code block in Step 6 and prepend this comment to the package declaration:

```go
// These tests validate that this service's client code only uses operations and fields
// declared in <service>@<version>. Any field, parameter, or path not in the spec will
// cause a test failure — this is intentional. The spec is the contract; the tests
// enforce it.
package <package>_test
```

(Replace the existing `package <package>_test` line at the top of the code block.)

- [ ] **Step 2: Update the Step 6 announce**

Find the existing announce block:

```
> "Generated `pact_consumer_test.go`. Running the tests will spin up pact-go's mock server, verify interactions, and write `pacts/<consumer>-<provider>.json` automatically:
```

Replace with:

```
> "Generated `pact_consumer_test.go`. These tests do two things:
> 1. **Validate client code against the spec** — if the implementation accesses a field not declared in `<service>@<version>`, calls an undeclared path, or uses a wrong parameter name, the test fails. This is the anti-hallucination guarantee: the spec is the only source of truth and the tests enforce it.
> 2. **Produce the pact contract artifact** — running the tests writes `pacts/<consumer>-<provider>.json` for use with a Pact Broker.
>
> Run:
> ```
> go test ./... -run TestPactConsumer
> ```
> See Pact Go docs: https://docs.pact.io/implementation_guides/go"
```

- [ ] **Step 3: Run anti-hallucination tests**

```bash
bash tests/claude-code/test-api-pact-generate.sh 2>&1 | grep -E "Test (9|10)|PASS|FAIL"
```

Expected: Tests 9–10 pass.

- [ ] **Step 4: Commit**

```bash
git add skills/api-pact-generate/SKILL.md
git commit -m "feat: add anti-hallucination framing to api-pact-generate consumer tests"
```

---

## Task 5: Fix terminology (verification → validation)

Replace all user-facing instances of "verification" with "validation". Pact-go API identifiers are unchanged.

**Files:**
- Modify: `skills/api-pact-generate/SKILL.md`

- [ ] **Step 1: Find all user-facing occurrences**

```bash
grep -n "verif" skills/api-pact-generate/SKILL.md
```

Expected output: only lines with `verifier`, `VerifyProvider`, `VerifyRequest`, `verifies` (describing pact-go internals). If any user-facing "verification" remains, fix it.

- [ ] **Step 2: Fix any remaining user-facing instances**

In any announce text, option label, or section heading, replace "verification" → "validation". Leave Go code identifiers (`NewVerifier`, `VerifyProvider`, `VerifyRequest`) and the comment "pact-go verifies the type matches" unchanged — these are library names and internal descriptions.

- [ ] **Step 3: Run terminology test**

```bash
bash tests/claude-code/test-api-pact-generate.sh 2>&1 | grep -E "Test 11|PASS|FAIL"
```

Expected: Test 11 passes.

- [ ] **Step 4: Commit**

```bash
git add skills/api-pact-generate/SKILL.md
git commit -m "fix: use validation instead of verification in user-facing text"
```

---

## Task 6: Version bump and wire test into run-all

**Files:**
- Modify: `package.json`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `tests/claude-code/run-all.sh`

- [ ] **Step 1: Run the full test suite to confirm all 11 tests pass**

```bash
bash tests/claude-code/test-api-pact-generate.sh
```

Expected: `=== All api-pact-generate tests passed ===`

- [ ] **Step 2: Bump version in all three files**

In `package.json`:
```json
{
  "name": "pinky-promise",
  "version": "0.0.2"
}
```

In `.claude-plugin/plugin.json`, change `"version": "0.0.1"` → `"version": "0.0.2"`.

In `.claude-plugin/marketplace.json`, change `"version": "0.0.1"` → `"version": "0.0.2"`.

- [ ] **Step 3: Add the new test to run-all.sh**

In `tests/claude-code/run-all.sh`, add after the last `run_test` line and before the summary block:

```bash
run_test "$SCRIPT_DIR/test-api-pact-generate.sh"
```

- [ ] **Step 4: Run the full suite**

```bash
bash tests/claude-code/run-all.sh
```

Expected: all tests pass, including `test-api-pact-generate`.

- [ ] **Step 5: Commit and open PR**

```bash
git add package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json tests/claude-code/run-all.sh
git commit -m "chore: bump to 0.0.2, wire pact-generate tests into run-all"
```

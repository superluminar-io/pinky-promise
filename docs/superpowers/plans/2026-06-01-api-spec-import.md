# api-spec-import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/api-spec-import` slash command that converts external API specs (OpenAPI, gRPC, GraphQL) into pinky-promise IDL entries in the registry, and wire import suggestions into the brainstorming, writing-plans, and api-contract-check hooks.

**Architecture:** Three SKILL.md files change (new `api-spec-import`, updated `api-contract-check`, updated `CLAUDE.md`) plus a new test scenario. The import skill fetches the source spec, detects format, converts to IDL JSON, applies the selected mode (full/auto/subset), proposes a semver bump, and writes to the registry via git. No code — all Claude skill instructions.

**Tech Stack:** Bash (curl, git, grep), Python 3 (test harness), Claude Code headless CLI

---

### Task 1: Add import suggestion to api-contract-check

**Files:**
- Modify: `skills/api-contract-check/SKILL.md` (Step 3 — unregistered service block)

- [ ] **Step 1: Read the current Step 3 block**

  Open `skills/api-contract-check/SKILL.md` and locate this text in Step 3:

  ```
  If the service directory does not exist:
  > "Warning: [service-name] has no published spec in the registry. Skipping contract check for this service."
  ```

- [ ] **Step 2: Replace the warning with an import suggestion**

  Replace:
  ```markdown
  If the service directory does not exist:
  > "Warning: [service-name] has no published spec in the registry. Skipping contract check for this service."
  ```

  With:
  ```markdown
  If the service directory does not exist:
  > "Warning: **[service-name]** has no entry in the registry. Run `/api-spec-import <url-to-spec>` to register it and enable contract checking. Skipping contract check for this service."
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add skills/api-contract-check/SKILL.md
  git commit -m "feat: surface import suggestion in api-contract-check for unknown services"
  ```

---

### Task 2: Add import hooks to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add brainstorming hook for external dependencies**

  In `CLAUDE.md`, locate the `## During brainstorming` section. Append a new bullet after the existing two:

  ```markdown
  - If the brainstorm mentions **calling an external service** (a service not developed in this repo) and no registry entry exists for it: you MUST surface this before the brainstorm concludes:
    > "The design depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."
  ```

- [ ] **Step 2: Add writing-plans hook for external dependencies**

  In `CLAUDE.md`, locate the `## During writing-plans` section. Append a new bullet after the existing two:

  ```markdown
  - If the plan involves **calling an external service** with no registry entry: you MUST surface this before the plan is finalized:
    > "The plan depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before finalizing this plan."
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add CLAUDE.md
  git commit -m "feat: add import suggestion hooks to brainstorming and writing-plans"
  ```

---

### Task 3: Write the api-spec-import skill

**Files:**
- Create: `skills/api-spec-import/SKILL.md`

- [ ] **Step 1: Create the skill file**

  Create `skills/api-spec-import/SKILL.md` with this exact content:

  ````markdown
  ---
  name: api-spec-import
  description: "Import an external API spec (OpenAPI, gRPC, GraphQL) into the pinky-promise registry as a declared dependency. Typical triggers: '/api-spec-import <url>', 'import the stripe spec', 'register this external API', 'add twilio to the registry'."
  argument-hint: <url-or-file> [--full|--subset|--auto]
  ---

  # API Spec Import

  Import an external API spec into the pinky-promise registry as a declared dependency, so `api-contract-check` can validate consumer code against it.

  ## When invoked

  - User runs `/api-spec-import <source> [--full|--subset|--auto]`
  - `<source>` is a URL or local file path to an OpenAPI 3.x/2.x (JSON/YAML), gRPC `.proto`, or GraphQL SDL file
  - Mode defaults to `--auto` if not specified

  ## Steps

  ### 1. Announce

  > "Running api-spec-import to register external API spec."

  ### 2. Resolve API_REGISTRY_REPO

  Check in order:
  1. `echo $API_REGISTRY_REPO`
  2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
  3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

  If not found:
  > "API_REGISTRY_REPO is not configured. Set it in your project CLAUDE.md or .claude/settings.json. See docs/registry-setup.md."

  Stop.

  ### 3. Fetch the spec

  If `<source>` is a URL:
  ```bash
  curl -fsSL "<source>" -o /tmp/api-spec-import-source
  ```

  If this fails:
  > "Could not fetch spec from `<source>`. Check the URL is reachable or provide a local file path instead."

  Stop.

  If `<source>` is a local file path, read it directly with the Read tool.

  ### 4. Detect format

  Inspect the content:
  - JSON/YAML containing `"openapi":` or `openapi:` at the top level → OpenAPI 3.x
  - JSON/YAML containing `"swagger":` or `swagger:` at the top level → OpenAPI 2.x (Swagger)
  - Contains `syntax = "proto` → gRPC Protocol Buffers
  - Contains `type Query`, `type Mutation`, or `schema {` → GraphQL SDL

  If format cannot be determined:
  > "Format not recognised. Supported: OpenAPI 3.x/2.x (JSON/YAML), gRPC .proto, GraphQL SDL."

  Stop.

  ### 5. Derive service name and external version

  **OpenAPI**: derive name from `info.title` converted to kebab-case (e.g. "Stripe API" → `stripe-api`). Take `info.version` as `external_version`.

  **gRPC**: derive name from the proto `package` declaration converted to kebab-case. Ask the user for a version string if the proto does not declare one.

  **GraphQL**: ask the user for both service name (kebab-case) and version string.

  Confirm with the user:
  > "Service name: `<derived-name>`, external version: `<external-version>`. Press enter to confirm or provide corrections."

  ### 6. Check for existing registry entry

  ```bash
  git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-import
  ```

  If clone fails:
  > "Registry unreachable. Check your SSH key and API_REGISTRY_REPO value."

  Stop.

  ```bash
  ls /tmp/api-registry-import/services/<service-name>/ 2>/dev/null | sort -V | tail -1
  ```

  If a previous entry exists, read it:
  ```bash
  cat /tmp/api-registry-import/services/<service-name>/<latest-version>.json
  ```

  Note the previously declared operations list — needed for re-import diff in step 8.

  ### 7. Convert to IDL

  Convert the fetched spec to pinky-promise IDL JSON using the following mapping:

  | Format | → Operations | → Events | → Types | → Bindings |
  |---|---|---|---|---|
  | OpenAPI 3.x/2.x | paths + HTTP methods | webhooks section | $ref schemas | http + environments from `servers` |
  | gRPC (unary RPC) | RPC methods | — | message types | grpc + environments |
  | gRPC (server-streaming) | server-streaming RPCs | — | message types | grpc + environments |
  | gRPC (client-streaming) | — | client-streaming RPCs | message types | grpc + environments |
  | GraphQL | queries + mutations | — | object types | graphql + environments |
  | GraphQL subscriptions | — | subscriptions → IDL subscriptions | object types | graphql + environments |

  Naming rules:
  - Member names (operation names, parameter names, field names): camelCase
  - Type names: PascalCase
  - Service name: kebab-case (already determined in step 5)

  Binding format — use named environments, populate `url` from the spec's server definitions, leave `auth` blocks empty:
  ```json
  "bindings": [{
    "protocol": "<http|grpc|graphql>",
    "environments": {
      "<env-name>": {
        "url": "<server-url-from-spec>",
        "auth": {}
      }
    }
  }]
  ```

  If the source spec has only one server URL, use `"default"` as the environment name.

  Do **not** write anything yet — hold the converted IDL in context.

  ### 8. Apply mode

  **`--full`**

  Use all converted operations. Proceed to step 9.

  ---

  **`--auto`** (default)

  Scan the current codebase for references to `<service-name>` or its client class:
  ```bash
  grep -r "<service-name>\|<ServiceNameClient>\|<ServiceName>Client" . \
    --include="*.ts" --include="*.tsx" --include="*.js" \
    --include="*.py" --include="*.go" --include="*.java" \
    -l 2>/dev/null
  ```

  Read the matched files. Identify which operation names from the converted IDL are referenced (method calls, string references, imports).

  **First import:**
  > "Detected these operations in your codebase: [list].
  > Confirm to import with this set, or name operations to add/remove."

  **Re-import:**
  > "Previously declared: [previous list]
  > Newly detected in codebase: [additions]
  > No longer detected in codebase: [removals]
  > Confirm to proceed, or name operations to add/remove."

  Wait for confirmation before proceeding.

  ---

  **`--subset`**

  List all operations from the converted IDL.

  **First import:** pre-select operations detected in the codebase (same scan as `--auto`).
  **Re-import:** pre-select previously declared operations.

  Present as a selection list:
  > "Select operations to import (marked items are pre-selected):
  >
  > [x] createCharge
  > [ ] updateCharge
  > [x] retrieveCharge
  > [x] listCharges
  > ...
  >
  > Type operation names to toggle selection, or 'done' to confirm."

  Wait for 'done' before proceeding.

  ### 9. Determine pinky-promise version

  **First import:** version is `1.0.0`.

  **Re-import:** compare the confirmed operation set against the previous entry:
  - Operations or types added only → minor bump (e.g. `1.0.0` → `1.1.0`)
  - Operations removed or input/output signatures changed → major bump (e.g. `1.0.0` → `2.0.0`)
  - Only description or metadata changes → patch bump (e.g. `1.0.0` → `1.0.1`)

  Propose to user:
  > "Proposed version: `<new-version>` (<bump-type> bump — <reason>). Press enter to confirm or type a different version."

  ### 10. Assemble and write the IDL entry

  Build the final IDL JSON:
  ```json
  {
    "name": "<service-name>",
    "version": "<pinky-promise-version>",
    "_source": {
      "url": "<source>",
      "external_version": "<external-version>",
      "imported_at": "<YYYY-MM-DD>"
    },
    "operations": [ ...confirmed operations only... ],
    "events": [ ...confirmed events only... ],
    "subscriptions": [ ...confirmed subscriptions only... ],
    "types": { ...types referenced by confirmed members only... },
    "bindings": [ ...with named environments, auth blocks empty... ]
  }
  ```

  Omit `events`, `subscriptions`, or `types` keys if empty.

  Write to registry:
  ```bash
  mkdir -p /tmp/api-registry-import/services/<service-name>
  ```

  Write the JSON to `/tmp/api-registry-import/services/<service-name>/<pinky-promise-version>.json`.

  ```bash
  cd /tmp/api-registry-import
  git add services/<service-name>/<version>.json
  git commit -m "<service-name>: <version> (import) — imported from <source>"
  git push
  cd -
  rm -rf /tmp/api-registry-import
  ```

  If `git push` fails:
  > "Registry write failed (git push error). The converted IDL is shown below — copy it and push manually."

  Display the full JSON. Do not stop the session.

  ### 11. Confirm

  > "Imported `<service-name>` v<pinky-promise-version> (external: <external-version>) into the registry. `api-contract-check` will now validate calls against this spec."

  If any `auth` blocks are present and empty:
  > "Note: `auth` blocks in bindings are empty. Edit the registry entry directly to add authentication configuration once the binding-spec-extension design is implemented."
  ````

- [ ] **Step 2: Commit**

  ```bash
  git add skills/api-spec-import/SKILL.md
  git commit -m "feat: add api-spec-import skill"
  ```

---

### Task 4: Add test scenario for api-spec-import

**Files:**
- Create: `tests/import-external-spec/prompts/import-openapi.txt`
- Create: `tests/import-external-spec/run-test.sh`

The test verifies that invoking `/api-spec-import` causes the `api-spec-import` skill to trigger. It uses the public Petstore OpenAPI spec as a stable, always-available test source. The test does not require a real registry — `API_REGISTRY_REPO` is set to a dummy value which causes the skill to announce and attempt step 2, which is enough to confirm triggering.

- [ ] **Step 1: Write the test prompt**

  Create `tests/import-external-spec/prompts/import-openapi.txt`:

  ```
  /api-spec-import https://petstore3.swagger.io/api/v3/openapi.json --auto
  ```

- [ ] **Step 2: Write the test runner**

  Create `tests/import-external-spec/run-test.sh`:

  ```bash
  #!/usr/bin/env bash
  # Test: /api-spec-import triggers api-spec-import skill
  #
  # Verifies that the api-spec-import slash command causes pinky-promise to
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
  ```

- [ ] **Step 3: Make executable**

  ```bash
  chmod +x tests/import-external-spec/run-test.sh
  ```

- [ ] **Step 4: Run the test — expect FAIL**

  ```bash
  tests/import-external-spec/run-test.sh
  ```

  Expected: `FAIL: api-spec-import was NOT triggered` (skill not yet created)

- [ ] **Step 5: Confirm Task 3 is complete, then re-run — expect PASS**

  After Task 3 is committed:

  ```bash
  tests/import-external-spec/run-test.sh
  ```

  Expected:
  ```
  PASS: api-spec-import was triggered
  Skills triggered:
  "skill":"pinky-promise:api-spec-import"
  All tests passed.
  ```

- [ ] **Step 6: Update tests/README.md — add the new scenario**

  In `tests/README.md`, append under `## Scenarios`:

  ```markdown
  ### import-external-spec

  A slash command invocation of `/api-spec-import` with a public OpenAPI spec URL.

  **Asserts:** `api-spec-import` skill is invoked when the user requests an external spec import.
  ```

- [ ] **Step 7: Commit**

  ```bash
  git add tests/import-external-spec/ tests/README.md
  git commit -m "test: add import-external-spec scenario for api-spec-import skill"
  ```

# pinky-promise Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that manages API contracts between producer and consumer services across all stages of the superpowers development workflow.

**Architecture:** Pure skills plugin (no runnable code). Four skill files define what Claude does at each stage. A `CLAUDE.md` injects trigger instructions into every session. An external git repo serves as the versioned spec registry. All registry writes are automated via the `api-spec-publish` skill.

**Tech Stack:** Markdown skill files, JSON (IDL format), git (registry transport)

---

### Task 1: Project scaffold and example spec

**Files:**
- Create: `README.md`
- Create: `examples/user-service/1.0.0.json`

- [ ] **Step 1: Create README.md**

```markdown
# claude-api-plugin

A Claude Code plugin for managing API contracts between producer and consumer services.

## Requirements

- Claude Code with superpowers plugin installed

## Setup

1. Create a dedicated git repository for your API registry (see `docs/registry-setup.md`)
2. In your project's CLAUDE.md, add:
   ```
   API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
   ```
3. Install this plugin

## Usage

See `docs/idl-reference.md` for the spec format and `docs/registry-setup.md` for registry setup.
```

- [ ] **Step 2: Create the example spec**

Create `examples/user-service/1.0.0.json`:

```json
{
  "name": "user-service",
  "version": "1.0.0",
  "description": "Manages users and authentication",
  "operations": [
    {
      "name": "getUser",
      "kind": "operation",
      "input": {
        "userId": { "type": "string" }
      },
      "output": { "type": "User" }
    },
    {
      "name": "createUser",
      "kind": "operation",
      "input": {
        "name": { "type": "string" },
        "email": { "type": "string" },
        "age": { "optional": true, "type": "number" }
      },
      "output": { "type": "User" }
    }
  ],
  "events": [
    {
      "name": "userCreated",
      "kind": "event",
      "payload": { "type": "User" }
    }
  ],
  "subscriptions": [
    {
      "name": "watchUser",
      "kind": "subscription",
      "input": {
        "userId": { "type": "string" }
      },
      "output": { "type": "User" }
    }
  ],
  "types": {
    "User": {
      "kind": "object",
      "fields": {
        "id": { "type": "string" },
        "name": { "type": "string" },
        "email": { "type": "string" },
        "age": { "optional": true, "type": "number" },
        "status": { "type": "UserStatus" }
      }
    },
    "UserStatus": {
      "kind": "enum",
      "values": ["active", "inactive", "banned"]
    }
  },
  "bindings": [
    {
      "protocol": "http-json-rest",
      "operations": {
        "getUser": { "method": "GET", "path": "/users/{userId}" },
        "createUser": { "method": "POST", "path": "/users" }
      },
      "connection": {
        "url": "https://api.example.com/v1"
      }
    },
    {
      "protocol": "grpc",
      "service": "UserService",
      "operations": {
        "getUser": { "rpc": "GetUser" },
        "createUser": { "rpc": "CreateUser" }
      }
    }
  ]
}
```

- [ ] **Step 3: Verify example is valid**

Check against the IDL rules in `docs/superpowers/specs/2026-06-01-api-contract-plugin-design.md`:

- All `kind` values are `operation`, `event`, or `subscription` ✓
- All type references in `input`/`output`/`payload` are either inline expressions or names in `types` ✓
- No inline `enum`, `union`, or `object` in field positions (all are in `types`) ✓
- `bindings` is present and non-empty ✓
- All operations referenced in `bindings.operations` exist in top-level `operations` ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add README.md examples/
git commit -m "feat: add project scaffold and example IDL spec"
```

---

### Task 2: IDL reference documentation

**Files:**
- Create: `docs/idl-reference.md`

- [ ] **Step 1: Write IDL reference**

Create `docs/idl-reference.md`:

```markdown
# IDL Reference

API specs are JSON files. One file per service version, stored in the registry as `services/<name>/<version>.json`.

## Top-level fields

| Field | Required | Description |
|---|---|---|
| `name` | yes | Service name, kebab-case (e.g. `user-service`) |
| `version` | yes | Semver string (e.g. `1.2.0`) |
| `description` | no | Human-readable description |
| `operations` | no | Array of request/response operations |
| `events` | no | Array of fire-and-forget events |
| `subscriptions` | no | Array of ongoing stream subscriptions |
| `types` | no | Map of named type definitions |
| `bindings` | yes | Array of transport binding declarations |

## Interface members

### operation

Request/response. Caller sends `input`, receives `output`.

```json
{
  "name": "getUser",
  "kind": "operation",
  "input": { "userId": { "type": "string" } },
  "output": { "type": "User" }
}
```

### event

Fire-and-forget. Producer emits `payload`, no response.

```json
{
  "name": "userCreated",
  "kind": "event",
  "payload": { "type": "User" }
}
```

### subscription

Ongoing stream. Consumer subscribes with `input`, receives repeated `output`.

```json
{
  "name": "watchUser",
  "kind": "subscription",
  "input": { "userId": { "type": "string" } },
  "output": { "type": "User" }
}
```

## Input, output, and payload fields

These fields accept either an inline object map of named fields or a single type expression:

```json
"input": { "userId": { "type": "string" } }           // inline object: field name → type expression
"output": { "type": "User" }                            // type reference
"output": { "type": "array", "items": { "type": "string" } }
"payload": { "type": "OrderEvent" }
```

## Deprecation

Any member can be marked deprecated:

```json
{
  "name": "getUser",
  "kind": "operation",
  "deprecated": {
    "message": "Use getUserV2 instead",
    "sunsetVersion": "3.0.0"
  },
  "input": { "userId": { "type": "string" } },
  "output": { "type": "User" }
}
```

`sunsetVersion` is optional. Deprecation is informational — it signals intent for the next major version but does not gate removal.

## Inline type expressions

Used directly in `input`, `output`, `payload`, and object field definitions:

```json
{ "type": "string" }
{ "type": "number" }
{ "type": "boolean" }
{ "type": "null" }
{ "type": "array", "items": { "type": "string" } }
{ "type": "MyType" }
{ "optional": true, "type": "string" }
```

`MyType` must be defined in the `types` map.

## Named types (`types` map)

`object`, `enum`, and `union` must be defined as named types. They cannot appear inline.

### object

```json
"User": {
  "kind": "object",
  "fields": {
    "id": { "type": "string" },
    "name": { "type": "string" },
    "age": { "optional": true, "type": "number" },
    "status": { "type": "UserStatus" }
  }
}
```

### enum

```json
"UserStatus": {
  "kind": "enum",
  "values": ["active", "inactive", "banned"]
}
```

### union

```json
"UserId": {
  "kind": "union",
  "variants": [{ "type": "string" }, { "type": "number" }]
}
```

Named types may reference other named types. Circular references are not allowed.

## Bindings

Each binding maps the abstract interface to a transport and optionally declares connection properties.

```json
{
  "protocol": "http-json-rest",
  "operations": {
    "getUser": { "method": "GET", "path": "/users/{userId}" },
    "createUser": { "method": "POST", "path": "/users" }
  },
  "connection": { "url": "https://api.example.com/v1" }
}
```

| Field | Required | Description |
|---|---|---|
| `protocol` | yes | Transport identifier (e.g. `http-json-rest`, `grpc`, `graphql`) |
| `operations` | no | Map of operation name → binding-specific config |
| `events` | no | Map of event name → binding-specific config |
| `subscriptions` | no | Map of subscription name → binding-specific config |
| `connection` | no | Connection properties (URL, port, etc.) — omit when env-specific |

Multiple bindings per service are allowed (e.g. `http-json-rest` and `grpc`).

## Semver rules

| Change | Bump |
|---|---|
| Add operation, event, subscription, or optional field | minor |
| Remove or change any operation, event, subscription, or type | major |
| Deprecate any member | minor |
| Change descriptions or connection properties | patch |

Major bumps have no constraints on shape — v2 is a clean slate with no obligations to v1.
```

- [ ] **Step 2: Review reference for completeness**

Check that every IDL construct in the design spec (`docs/superpowers/specs/2026-06-01-api-contract-plugin-design.md`) has a corresponding example here. Check that the semver table matches the design spec exactly.

Expected: no gaps.

- [ ] **Step 3: Commit**

```bash
git add docs/idl-reference.md
git commit -m "docs: add IDL format reference"
```

---

### Task 3: Registry setup documentation

**Files:**
- Create: `docs/registry-setup.md`

- [ ] **Step 1: Write registry setup guide**

Create `docs/registry-setup.md`:

```markdown
# Registry Setup

The API registry is a separate git repository. All writes come from the `api-spec-publish` skill — no human commits.

## Creating the registry

```bash
mkdir api-registry
cd api-registry
git init
mkdir -p services
git add services
git commit --allow-empty -m "chore: init registry"
git remote add origin git@github.com:yourorg/api-registry.git
git push -u origin main
```

## Configuring the registry URL

In your project's CLAUDE.md:

```
API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
```

Or in `.claude/settings.json`:

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:yourorg/api-registry.git"
  }
}
```

## Registry layout

```
api-registry/
  services/
    user-service/
      1.0.0.json
      1.1.0.json
      2.0.0.json
    payment-service/
      1.0.0.json
```

One JSON file per service version, named by semver. The highest semver in a directory is the latest version. Published versions are immutable.

## Commit format

Every publish creates a commit in the format:

```
<service-name>: <version> (<bump>) — <summary>
```

Examples:
```
user-service: 1.1.0 (minor) — added listUsers operation
user-service: 2.0.0 (major) — removed deprecated getUser, redesigned auth model
payment-service: 1.0.1 (patch) — updated connection URL
```

## Authentication

Skills use standard git over SSH. The machine running Claude Code must have SSH access configured for the registry repo.
```

- [ ] **Step 2: Commit**

```bash
git add docs/registry-setup.md
git commit -m "docs: add registry setup guide"
```

---

### Task 4: `api-spec-brainstorming` skill

**Files:**
- Create: `skills/api-spec-brainstorming/SKILL.md`

- [ ] **Step 1: Define expected behavior (test scenario)**

Scenario: User is brainstorming a new `order-service`. No spec exists in the registry.

Expected:
1. Skill announces itself
2. Infers or asks for service name
3. Asks what operations to expose, one at a time, capturing inputs and outputs
4. Asks about events emitted
5. Asks about subscriptions supported
6. Extracts shared shapes into named types
7. Asks about transport bindings
8. Produces a complete draft IDL JSON and states it is ready for `api-spec-publish`

- [ ] **Step 2: Write the skill**

Create `skills/api-spec-brainstorming/SKILL.md`:

```markdown
# API Spec Brainstorming

Define the public API surface of a service in parallel with the superpowers brainstorming skill.

## When invoked

- A new service is being brainstormed and has no published spec in the registry
- A major version bump is being planned and the new API is being designed from scratch

## What to do

Announce: "Running api-spec-brainstorming to define the public API surface alongside the design brainstorm."

Work through these questions one at a time. Use the answers to build toward the draft IDL.

### 1. Identify the service name

Infer from the project directory name or any draft content in context. If ambiguous:
> "What is the canonical name for this service? (kebab-case, e.g. `order-service`)"

### 2. Identify public operations

Ask:
> "What operations does [service-name] need to expose to other services? These are the request/response calls other services will make."

For each operation named:
- Ask for input parameters (names and types)
- Ask for the return value
- Ask: "Is this truly part of the public contract, or is it an internal implementation detail?"

Drop anything the user identifies as internal.

### 3. Identify events

Ask:
> "Does [service-name] emit any events that other services would react to? (fire-and-forget — no response expected)"

For each event, ask for the payload structure.

If none, proceed.

### 4. Identify subscriptions

Ask:
> "Does [service-name] support any ongoing streams or subscriptions — where a caller receives repeated data over time?"

For each subscription, ask for input (what the subscriber provides) and output (what they receive).

If none, proceed.

### 5. Extract shared types

Review all inputs, outputs, and payloads collected. Identify shapes that appear more than once or that are complex enough to name. Propose names for them (PascalCase).

State: "I'll define these as named types: [list]."

### 6. Ask about bindings

Ask:
> "How is [service-name] exposed? (e.g. HTTP JSON REST, gRPC, GraphQL, message queue)"

For each binding:
- Ask for the protocol-specific mapping of operations (e.g. HTTP method and path for REST, RPC name for gRPC)
- Ask: "Is there a known connection URL to include?"

`connection` is optional — if the URL varies by environment, omit it.

### 7. Produce the draft IDL

Synthesize all answers into a valid IDL JSON following the format in `docs/idl-reference.md`. Use version `1.0.0` for all first-time specs.

State it explicitly:

> "Draft spec for [service-name]:
>
> ```json
> { ... }
> ```
>
> This draft will be published when api-spec-publish is invoked."

## Validation rules to enforce

- No inline `enum`, `union`, or `object` — define them in the `types` map
- All type references in `input`/`output`/`payload` are either inline type expressions or names defined in `types`
- `bindings` must have at least one entry
- Member names are camelCase
- Type names are PascalCase
- Service name is kebab-case
```

- [ ] **Step 3: Review skill against expected behavior**

Check each item from Step 1:
- Announces itself ✓
- Identifies service name ✓
- Asks about operations with inputs/outputs and public/internal distinction ✓
- Asks about events ✓
- Asks about subscriptions ✓
- Extracts shared types ✓
- Asks about bindings including connection URL ✓
- Produces draft IDL with explicit statement it's ready for publish ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add skills/api-spec-brainstorming/
git commit -m "feat: add api-spec-brainstorming skill"
```

---

### Task 5: `api-change-guardian` skill

**Files:**
- Create: `skills/api-change-guardian/SKILL.md`

- [ ] **Step 1: Define expected behavior (test scenarios)**

Scenario A — removal (major): User proposes removing `getUser` from `user-service` (currently `1.2.0`).
Expected: classifies major, prompts "bump to 2.0.0 / find backwards-compatible approach / defer".

Scenario B — addition (minor): User proposes adding `listUsers` to `user-service`.
Expected: classifies minor, prompts "bump to 1.3.0 / find backwards-compatible approach / defer".

Scenario C — registry unreachable.
Expected: warns and skips without blocking work.

Scenario D — user defers.
Expected: records "Deferred: [description]" explicitly in conversation.

- [ ] **Step 2: Write the skill**

Create `skills/api-change-guardian/SKILL.md`:

```markdown
# API Change Guardian

Detect changes to a published API spec and force a conscious versioning decision.

## When invoked

Any stage (brainstorming, planning, implementation, review) proposes a change that would affect the public API surface of a service with a published spec.

## What to do

Announce: "Running api-change-guardian to check for API contract changes."

### Step 1: Identify the service

Infer the service name from the draft spec in context or the project directory name. If ambiguous, ask.

### Step 2: Locate API_REGISTRY_REPO

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Skipping contract check. See docs/registry-setup.md."

Stop.

### Step 3: Clone the registry

```bash
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-check
```

If clone fails:
> "Registry unreachable (clone failed). Skipping contract check. Work can continue — changes are unvalidated."

Stop.

### Step 4: Find the current published spec

```bash
ls /tmp/api-registry-check/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

If no versions exist, this is a new service — no published contract to check. Clean up and stop.

Read the spec:
```bash
cat /tmp/api-registry-check/services/<service-name>/<current-version>.json
```

### Step 5: Identify proposed changes

From the conversation context, determine exactly what is changing:
- Which operations/events/subscriptions are being added, removed, or changed
- Which types are being added, removed, or changed
- Which descriptions or connection properties are changing

List each change explicitly before classifying.

### Step 6: Classify

Apply these rules to each change:

| Change | Classification |
|---|---|
| Remove or change an existing operation, event, subscription, or type | **major** |
| Add a new operation, event, or subscription | **minor** |
| Add an optional field to an existing type | **minor** |
| Deprecate a member | **minor** |
| Change a description or connection property | **patch** |

The overall classification is the highest across all individual changes (major > minor > patch).

Calculate the new version by applying the bump to `<current-version>`.

### Step 7: Prompt the user

> "This change is a **[major/minor/patch]** change to [service-name] (currently [current-version]).
>
> Changes detected:
> - [change 1]
> - [change 2]
>
> How would you like to proceed?
> 1. Proceed — bump to [new-version] when publishing
> 2. Find a backwards-compatible approach instead
> 3. Defer this decision"

### Step 8: Record the decision

**If proceeding:**
> "Recorded: [service-name] will bump to [new-version] ([major/minor/patch]) when published."

**If finding backwards-compatible approach:**
> "Understood. Let's find an approach that doesn't require a [major/minor] bump."
Collaborate on the alternative before continuing.

**If deferring:**
> "Deferred: [description of change]. This must be resolved before api-spec-publish runs."

Accumulate deferred decisions across multiple guardian runs in the same session. The final version bump at publish time is the highest classification across all resolved decisions.

### Clean up

```bash
rm -rf /tmp/api-registry-check
```
```

- [ ] **Step 3: Review skill against expected behavior**

Check each scenario from Step 1:
- Scenario A (removal → major): classification table ✓, prompts with 2.0.0 ✓
- Scenario B (addition → minor): classification table ✓, prompts with 1.3.0 ✓
- Scenario C (unreachable): Step 3 clone failure handling ✓
- Scenario D (defer): Step 8 records "Deferred:" explicitly ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add skills/api-change-guardian/
git commit -m "feat: add api-change-guardian skill"
```

---

### Task 6: `api-contract-check` skill

**Files:**
- Create: `skills/api-contract-check/SKILL.md`

- [ ] **Step 1: Define expected behavior (test scenarios)**

Scenario A — type mismatch: `api-dependencies.json` pins `user-service` at `1.2.0`. Implementation calls `getUser` passing `userId` as a number, but spec requires string.
Expected: flags "getUser: userId type mismatch — spec requires string, got number". Also reports "user-service 1.3.0 available (added listUsers)".

Scenario B — missing `api-dependencies.json`.
Expected: prompts to create it, lists available services and versions from registry, writes the file.

Scenario C — deprecated operation in use.
Expected: warns with deprecation message and sunset version.

Scenario D — pinned version missing from registry.
Expected: fails with message naming the missing version and registry URL.

- [ ] **Step 2: Write the skill**

Create `skills/api-contract-check/SKILL.md`:

```markdown
# API Contract Check

Validate the current implementation or plan against published API specs.

## When invoked

- Before finalizing a plan that calls another service
- During code review of consumer code
- When implementing code that calls an external service

## What to do

Announce: "Running api-contract-check to validate against published API specs."

### Step 1: Locate API_REGISTRY_REPO and clone

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Cannot run contract check. See docs/registry-setup.md."

Stop.

```bash
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-check
```

If clone fails:
> "Registry unreachable. Skipping contract check."

Stop.

### Step 2: Read api-dependencies.json

```bash
cat api-dependencies.json
```

If the file does not exist, prompt to create it:
> "No api-dependencies.json found. Which services does this project consume?"

List available services:
```bash
ls /tmp/api-registry-check/services/
```

For each service the user names, list available versions and ask which to pin:
```bash
ls /tmp/api-registry-check/services/<service-name>/ | sort -V
```

Write `api-dependencies.json` to the project root:
```json
{
  "<service-name>": "<pinned-version>"
}
```

Announce: "Created api-dependencies.json. Proceeding with contract check."

### Step 3: Fetch pinned specs

For each entry in `api-dependencies.json`:

First check whether the service exists in the registry at all:
```bash
ls /tmp/api-registry-check/services/<service-name>/ 2>/dev/null
```

If the service directory does not exist:
> "Warning: [service-name] has no published spec in the registry. Skipping contract check for this service."

Continue to the next dependency.

If the service exists, check for the pinned version:
```bash
cat /tmp/api-registry-check/services/<service-name>/<pinned-version>.json
```

If the file does not exist:
> "Error: [service-name] version [pinned-version] not found in registry ([API_REGISTRY_REPO]). Check api-dependencies.json."

Stop on this error.

### Step 4: Validate the implementation

For each pinned spec, check the current implementation or plan:

**Operations called:**
- Does each called operation exist in the spec?
- Do parameter names match exactly?
- Do parameter types match (string ≠ number, required ≠ optional)?
- Is the return type handled correctly?

**Events/subscriptions consumed:**
- Does each consumed event/subscription exist in the spec?
- Does the payload handling match the spec type?

Report each violation:
> "**[service-name]** — [member-name]: [description of violation]"

If no violations:
> "[service-name] v[pinned-version] — contract check passed."

### Step 5: Warn about deprecated usage

For each deprecated member in use:
> "Warning: **[service-name].[member-name]** is deprecated. [deprecated.message][. Sunset planned for v[deprecated.sunsetVersion] if present]."

### Step 6: Report available updates

For each pinned service, find the highest version within the same major:
```bash
MAJOR=$(echo "<pinned-version>" | cut -d. -f1)
ls /tmp/api-registry-check/services/<service-name>/ | sort -V | grep "^${MAJOR}\." | tail -1
```

If a newer compatible version exists:
> "Update available: **[service-name]** [pinned-version] → [latest-compatible]. New in [latest-compatible]: [list operations/events/subscriptions added since pinned-version, found by comparing the two spec files]."

### Clean up

```bash
rm -rf /tmp/api-registry-check
```
```

- [ ] **Step 3: Review skill against expected behavior**

Check each scenario from Step 1:
- Scenario A (type mismatch + update available): Step 4 flags type issues ✓, Step 6 reports newer version ✓
- Scenario B (missing api-dependencies.json): Step 2 prompts and creates file ✓
- Scenario C (deprecated usage): Step 5 warns ✓
- Scenario D (pinned version missing): Step 3 fails with clear message ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add skills/api-contract-check/
git commit -m "feat: add api-contract-check skill"
```

---

### Task 7: `api-spec-publish` skill

**Files:**
- Create: `skills/api-spec-publish/SKILL.md`

- [ ] **Step 1: Define expected behavior (test scenarios)**

Scenario A — happy path: Draft spec for `user-service` in context. Guardian recorded one minor change (added `listUsers`) and one patch (updated URL). No deferred decisions. Current published version is `1.2.0`.
Expected: determines minor is highest → bumps to `1.3.0`. Updates version in draft. Writes `services/user-service/1.3.0.json`. Commits "user-service: 1.3.0 (minor) — added listUsers operation". Pushes.

Scenario B — unresolved deferred decisions.
Expected: lists them, refuses to publish until resolved.

Scenario C — no draft spec in context.
Expected: invokes `api-spec-brainstorming`, then continues.

Scenario D — registry unreachable.
Expected: fails hard with clear message.

- [ ] **Step 2: Write the skill**

Create `skills/api-spec-publish/SKILL.md`:

```markdown
# API Spec Publish

Publish a service's API spec to the registry.

## When invoked

- At `finishing-a-development-branch` when a draft spec or unresolved guardian decisions exist
- Manually when a producer wants to publish

## What to do

Announce: "Running api-spec-publish to publish the API spec to the registry."

### Step 1: Check for a draft spec

Look for a draft IDL JSON in the conversation context — produced by `api-spec-brainstorming` or accumulated through guardian-approved changes.

If no draft is present:
> "No draft spec found in context. Running api-spec-brainstorming first."

Invoke `api-spec-brainstorming`, then continue.

### Step 2: Check for unresolved deferred decisions

Scan the conversation for lines marked "Deferred:" from previous `api-change-guardian` runs.

If any exist:
> "Cannot publish: the following decisions must be resolved first:
> - [deferred decision 1]
> - [deferred decision 2]
>
> For each: proceed with the version bump, or find a backwards-compatible approach?"

Wait for each to be resolved before continuing.

### Step 3: Locate API_REGISTRY_REPO

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Cannot publish. See docs/registry-setup.md."

Stop.

Clone the registry (full clone — needed to push):
```bash
git clone "$API_REGISTRY_REPO" /tmp/api-registry-publish
```

If clone fails:
> "Registry unreachable. Cannot publish without registry access."

Stop.

### Step 4: Determine the version number

Check whether this service has been published before:
```bash
ls /tmp/api-registry-publish/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

**First publish:** No versions found → version is `1.0.0`.

**Subsequent publish:** Current version is the last result above. Apply the highest bump classification from all guardian decisions recorded in this session (major > minor > patch). If no guardian decisions were recorded, use the version already in the draft spec.

Calculate the new semver:
- patch: increment third number (1.2.3 → 1.2.4)
- minor: increment second number, reset third (1.2.3 → 1.3.0)
- major: increment first number, reset second and third (1.2.3 → 2.0.0)

Confirm with the user:
> "Ready to publish [service-name] as [new-version] ([bump]). Confirm? (yes/no)"

Wait for confirmation before proceeding.

### Step 5: Write and publish

Update the `version` field in the draft spec to `<new-version>`.

Create the service directory if needed:
```bash
mkdir -p /tmp/api-registry-publish/services/<service-name>
```

Write the spec file:
```bash
cat > /tmp/api-registry-publish/services/<service-name>/<new-version>.json << 'SPEC'
<full draft spec JSON>
SPEC
```

Verify the file:
```bash
cat /tmp/api-registry-publish/services/<service-name>/<new-version>.json
```

Commit:
```bash
cd /tmp/api-registry-publish
git add services/<service-name>/<new-version>.json
git commit -m "<service-name>: <new-version> (<bump>) — <one-line summary>"
```

The summary describes the most significant change (e.g. "added listUsers operation", "removed deprecated getUser", "updated connection URL").

Push:
```bash
git push origin main
```

### Step 6: Announce and clean up

> "Published [service-name] v[new-version] to the registry."

```bash
rm -rf /tmp/api-registry-publish
```
```

- [ ] **Step 3: Review skill against expected behavior**

Check each scenario from Step 1:
- Scenario A (happy path, minor bump): Steps 3-6 cover this end-to-end ✓
- Scenario B (unresolved deferred): Step 2 blocks and resolves ✓
- Scenario C (no draft): Step 1 invokes brainstorming ✓
- Scenario D (registry unreachable): Step 3 fails hard ✓
- User confirmation before publish: Step 4 confirms ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add skills/api-spec-publish/
git commit -m "feat: add api-spec-publish skill"
```

---

### Task 8: CLAUDE.md integration

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Define expected triggers (test)**

CLAUDE.md must cause Claude to:

1. Session start + `API_REGISTRY_REPO` + service has spec → fetch spec silently
2. Brainstorming + no published spec → invoke `api-spec-brainstorming` in parallel
3. Brainstorming + published spec + interface change proposed → invoke `api-change-guardian`
4. `writing-plans` + plan consumes another service → invoke `api-contract-check` before finalizing
5. `writing-plans` + plan changes current service's interface → invoke `api-change-guardian` before finalizing
6. `subagent-driven-development` + subagent code changes published interface → invoke `api-change-guardian`
7. `requesting-code-review` + consumer code → invoke `api-contract-check`
8. `requesting-code-review` + producer code → invoke `api-change-guardian`
9. `finishing-a-development-branch` + draft spec or unresolved guardian decisions → invoke `api-spec-publish`

- [ ] **Step 2: Write CLAUDE.md**

Create `CLAUDE.md`:

```markdown
# claude-api-plugin

This plugin manages API contracts between producer and consumer services. It integrates with the superpowers development workflow.

**Requires superpowers to be installed and active.**

## Configuration

Set the registry URL in this project's CLAUDE.md (below this file's content) or in `.claude/settings.json`:

```
API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
```

If `API_REGISTRY_REPO` is not set, all skills warn and skip silently — they never block work.

## Session start

If `API_REGISTRY_REPO` is configured:
1. Identify the current service name (from project directory or draft spec in context)
2. Check if a spec exists in the registry for this service
3. If yes, read it into context silently — do not announce this to the user

## During brainstorming (superpowers brainstorming skill)

- If the current service has **no published spec**: you MUST invoke `api-spec-brainstorming` in parallel with the brainstorm. Run both concurrently — do not wait for one to finish before starting the other.
- If the current service **has a published spec** and the brainstorm proposes changes to the public interface: you MUST invoke `api-change-guardian` before those changes are adopted into the design.

## During writing-plans (superpowers writing-plans skill)

- If the plan involves **calling another service**: you MUST invoke `api-contract-check` before the plan is finalized.
- If the plan proposes **changes to the current service's public interface**: you MUST invoke `api-change-guardian` before the plan is finalized.

## During subagent-driven-development (superpowers subagent-driven-development skill)

- If a subagent's proposed implementation would **change a published interface**: you MUST invoke `api-change-guardian` before approving that task's output.

## During requesting-code-review (superpowers requesting-code-review skill)

- For **consumer code** (code that calls another service): you MUST invoke `api-contract-check` as part of the review.
- For **producer code** (code that implements a service interface): you MUST invoke `api-change-guardian` as part of the review.

## During finishing-a-development-branch (superpowers finishing-a-development-branch skill)

- If a **draft spec** is present in context OR **unresolved guardian decisions** exist: you MUST invoke `api-spec-publish` before completing the branch.
```

- [ ] **Step 3: Review CLAUDE.md against expected triggers**

Check each item from Step 1:
1. Session start fetch ✓
2. Brainstorm + no spec → brainstorming ✓
3. Brainstorm + spec + change → guardian ✓
4. writing-plans + consumer → contract check ✓
5. writing-plans + interface change → guardian ✓
6. subagent + interface change → guardian ✓
7. code-review + consumer → contract check ✓
8. code-review + producer → guardian ✓
9. finishing-branch + draft/unresolved → publish ✓

Expected: all checks pass.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: add CLAUDE.md integration instructions"
```

---

### Task 9: Final review and verification

**Files:** None created — review only.

- [ ] **Step 1: Cross-check all skill files reference consistent names**

Verify:
- All four skills use `API_REGISTRY_REPO` as the environment variable name
- `/tmp/api-registry-check` is used in `api-change-guardian` and `api-contract-check`
- `/tmp/api-registry-publish` is used in `api-spec-publish` (separate path — avoids conflicts)
- All skills reference `docs/registry-setup.md` for setup instructions
- The term "draft spec" is used consistently across all skills and CLAUDE.md

- [ ] **Step 2: Verify full project structure**

Run:
```bash
find . -not -path './.git/*' -type f | sort
```

Expected output:
```
./CLAUDE.md
./README.md
./docs/idl-reference.md
./docs/registry-setup.md
./docs/superpowers/plans/2026-06-01-api-contract-plugin.md
./docs/superpowers/specs/2026-06-01-api-contract-plugin-design.md
./examples/user-service/1.0.0.json
./skills/api-change-guardian/SKILL.md
./skills/api-contract-check/SKILL.md
./skills/api-spec-brainstorming/SKILL.md
./skills/api-spec-publish/SKILL.md
```

- [ ] **Step 3: Commit the plan**

```bash
git add docs/superpowers/plans/2026-06-01-api-contract-plugin.md
git commit -m "docs: add implementation plan"
```

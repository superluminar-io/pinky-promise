# pinky-swear Design

**Date:** 2026-06-01
**Status:** Draft

## Problem

When building systems with superpowers, the workflow focuses on internal service behavior. There is no mechanism to define, publish, or validate the external API surface of a service — the contract between producers and consumers. This means API drift, breaking changes, and consumer/producer mismatches are caught late, if at all.

## Goals

1. Give producers a workflow to define and publish versioned API specs during development
2. Give consumers a way to validate their implementation against a published spec
3. Detect API changes at every stage of development and force conscious versioning decisions
4. Keep the API surface as stable as possible — changes are deliberate, never accidental

## Non-Goals

- Generating runtime client code from specs (contract validation only, not code generation)
- Supporting non-superpowers users on the consumer side (v1 targets superpowers users; specs remain human-readable for future portability)
- An MCP server or hosted registry (git repo only for v1)
- Per-environment config management beyond optional connection properties in bindings

## Design

### Plugin structure

```
claude-api-plugin/
  CLAUDE.md
  skills/
    api-spec-brainstorming/
      SKILL.md
    api-change-guardian/
      SKILL.md
    api-contract-check/
      SKILL.md
    api-spec-publish/
      SKILL.md
  docs/
    idl-reference.md
    registry-setup.md
  examples/
    user-service/
      1.0.0.json
```

Pure skills plugin — no code, no dependencies. Requires superpowers to be installed.

### Roles

**Producer** — owns a service, defines and publishes its API spec via `api-spec-brainstorming` and `api-spec-publish`.

**Consumer** — builds against another service's published spec, validated via `api-contract-check`. Declares dependencies in `api-dependencies.json`.

A session can be both producer and consumer simultaneously.

### Registry

A separate git repo, configured per project:

```
API_REGISTRY_REPO=git@github.com:myorg/api-registry.git
```

Set in the project's CLAUDE.md or `.claude/settings.json`.

Layout:
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

Two files per service: a versioned contract file (`<version>.json`) and a non-versioned `bindings.json`. The highest semver in a service directory is the latest contract. Published contract versions are immutable — `api-spec-publish` never overwrites an existing versioned file. `bindings.json` is always overwritten on publish. All commits are automated; no human commits. Commit message format:

```
user-service: 1.1.0 (minor) — added getUsers operation
```

Skills clone the registry to a temp directory on demand. Shallow clone (`--depth 1`) for reads; full clone for pushes. Always `rm -rf` the target path before cloning to prevent stale copies from a crashed previous session.

### Registry is the only source of truth

**No skill may read another service's code or spec files from the local filesystem.** This means no `find`, no directory traversal, no reading `.json`, `.proto`, `.go`, `.ts`, or any other file from outside the current working directory. Sibling service directories must never be consulted — even when they happen to be checked out next to the current project.

All contract data for any service other than the current one must come exclusively from a fresh clone of `API_REGISTRY_REPO` into `/tmp`. If the registry is unreachable or has no entry for a service, the skill says so and stops.

### IDL format

Each service has **two files** in the registry, with different versioning lifecycles:

```
services/
  user-service/
    1.2.0.json      ← abstract contract (versioned with semver)
    bindings.json   ← protocol mappings + connection URLs (not versioned)
```

**Contract file** (`<version>.json`) — the abstract API surface. No transport details.

```json
{
  "name": "user-service",
  "version": "1.2.0",
  "description": "Manages users and authentication",
  "operations": [
    {
      "name": "getUser",
      "kind": "operation",
      "description": "Fetch a user by ID. Use when you have a userId and need their profile.",
      "input": { "userId": { "type": "string" } },
      "output": { "type": "User" }
    }
  ],
  "events": [
    {
      "name": "userCreated",
      "kind": "event",
      "description": "Emitted after a user is persisted. React to trigger provisioning or welcome flows.",
      "payload": { "type": "User" }
    }
  ],
  "subscriptions": [
    {
      "name": "watchUser",
      "kind": "subscription",
      "description": "Stream live updates for a user. Prefer over polling getUser on an interval.",
      "input": { "userId": { "type": "string" } },
      "output": { "type": "User" }
    }
  ],
  "types": {
    "User": {
      "kind": "object",
      "fields": {
        "id": { "type": "string" },
        "name": { "type": "string" },
        "age": { "optional": true, "type": "number" }
      }
    },
    "Status": {
      "kind": "enum",
      "values": ["active", "inactive", "banned"]
    },
    "UserId": {
      "kind": "union",
      "variants": [{ "type": "string" }, { "type": "number" }]
    }
  }
}
```

**Bindings file** (`bindings.json`) — protocol mappings and connection URLs. Updated independently of the contract version; no semver bump required when bindings change.

```json
{
  "service": "user-service",
  "bindings": [
    {
      "protocol": "http-json-rest",
      "prefix": "/v1",
      "operations": {
        "getUser": { "method": "GET", "path": "/users/{userId}" }
      },
      "connection": { "url": "https://api.example.com" }
    }
  ]
}
```

The `description` field on operations, events, and subscriptions is used verbatim as the MCP tool description when the service is exposed via an MCP server — write it from the caller's perspective.

#### Interface member kinds

| Kind | Description |
|---|---|
| `operation` | Request/response — caller sends input, receives output |
| `event` | Fire-and-forget — producer emits, no response |
| `subscription` | Ongoing stream — consumer receives repeated output |

#### Input and output fields

The `input` and `output` fields on operations and subscriptions, and the `payload` field on events, accept either an inline object map of named fields or a single type expression:

```json
"input": { "userId": { "type": "string" } }         // inline object
"output": { "type": "User" }                         // type reference
"output": { "type": "array", "items": { "type": "string" } }
```

Both forms are valid. Use inline when the shape is simple and local; use a type reference when the shape is reused or complex.

#### Type system

**Inline type expressions** — used directly in `input`, `output`, `payload`, and field definitions:

```json
{ "type": "string" }                                         // primitive: string, number, boolean, null
{ "type": "array", "items": { "type": "string" } }          // array of any inline type
{ "type": "User" }                                           // reference to a named type in types map
{ "optional": true, "type": "string" }                      // optional wrapper on any inline type
```

**Named types** — defined in the `types` map, referenced by name. `object`, `enum`, and `union` must be declared here; they cannot appear inline:

```json
"Status": { "kind": "enum", "values": ["active", "inactive", "banned"] },
"UserId": { "kind": "union", "variants": [{ "type": "string" }, { "type": "number" }] },
"User": {
  "kind": "object",
  "fields": {
    "id": { "type": "string" },
    "name": { "type": "string" },
    "age": { "optional": true, "type": "number" }
  }
}
```

Variants in a union and items in an array are inline type expressions. Named types may reference other named types.

#### Bindings

Bindings live in `bindings.json` alongside the contract files, not inside the contract itself. They map the abstract interface to a transport and declare connection URLs. Multiple bindings per service are allowed. The `prefix` field is an optional path prefix prepended to all HTTP operation paths (e.g. `/v1`).

**Auth** — the producer declares the auth flow in `connection.auth`. This is a machine-readable specification of the protocol; credential values are never stored here. Supported types: `bearer`, `basic`, `api_key`, `oauth2` (flows: `client_credentials`, `password`). The consumer provides credential values in their own `.pinky-swear/credentials.json` (gitignored), mapping their own env vars to the standard protocol parameter names. The producer has no say in the consumer's variable naming.

**Versioning** — each binding entry carries an optional `contractVersion` field (`"1.*"`, `"2.*"`, or an exact version like `"1.5.0"`) so multiple deployed versions of the same service can coexist in the registry with different endpoints. A client pinned to `1.2.0` resolves the most specific matching binding.

See `docs/idl-reference.md` for the full schema including auth types, `credentials.json` format, and `contractVersion` matching rules.

#### Deprecation

Any operation, event, or subscription can carry deprecation metadata:

```json
{
  "name": "getUser",
  "kind": "operation",
  "deprecated": {
    "message": "Use getUserV2 instead",
    "sunsetVersion": "3.0.0"
  }
}
```

Deprecation is informational only — it signals intent for the next major version. It does not gate removal.

### Semver rules

| Change | Bump |
|---|---|
| Add operation, event, subscription, or optional field | minor |
| Remove or change any operation, event, subscription, or type | major |
| Add a required field to an existing type | major |
| Deprecate any member | minor |
| Change descriptions | patch |

Binding changes (paths, URLs, protocols) are not subject to semver — they are managed in `bindings.json` independently of the contract version.

Major bumps have no constraints on shape — v2 is a clean slate with no obligations to v1.

### Consumer dependencies

Each consumer project declares pinned versions in `api-dependencies.json` at the project root:

```json
{
  "user-service": "1.2.0",
  "payment-service": "1.0.0"
}
```

`api-contract-check` validates against the pinned version, not latest. If the file is missing, the skill prompts to create it. If a newer compatible version (same major, higher minor) exists in the registry, the skill reports it as an informational update — never a blocker.

### Skills

#### `api-spec-brainstorming`

Triggered in parallel with superpowers brainstorming when a service has no published spec yet. Runs a focused sub-conversation to identify the public API surface: which operations to expose, inputs and outputs, event types, subscription streams. Produces two artefacts persisted to disk so they survive across sessions:

- `.pinky-swear/draft-spec.json` — abstract contract (operations, events, subscriptions, types)
- `.pinky-swear/bindings.json` — protocol mappings and connection URLs (see IDL reference)

Neither is published until `api-spec-publish` runs.

#### `api-change-guardian`

Cross-cutting. Invoked whenever a proposed change in any stage would affect a published spec. Fetches the current published spec, compares it to the proposed state from conversation context, classifies the delta per the semver rules above, and prompts the user:

1. Proceed with the appropriate version bump
2. Find a backwards-compatible approach instead
3. Defer the decision

Deferred decisions are tracked and must be resolved before `api-spec-publish` runs.

#### `api-contract-check`

For consumers. Fetches the target service's contract at the pinned version and `bindings.json` from the registry and validates the current plan or implementation against both. Flags: missing required parameters, wrong types, calling undefined operations, incorrect HTTP paths or gRPC RPC names, missing error handling. Also reports whether a newer compatible version is available, including a summary of what was added.

#### `api-spec-publish`

Final step for producers. Reads `.pinky-swear/draft-spec.json` and `.pinky-swear/bindings.json` from disk (falling back to context if the files are absent), resolves any deferred guardian decisions (blocking if unresolved), determines the new version number, clones the registry, writes both the versioned contract file and `bindings.json`, commits with a descriptive message, and pushes. Deletes the `.pinky-swear/` draft files on success. If no draft exists, runs `api-spec-brainstorming` first. Fails hard if the registry is unreachable.

Version number is determined from the guardian decisions accumulated during the session: the highest classification across all resolved changes (major > minor > patch) sets the bump. If no guardian decisions exist (first publish), the version is `1.0.0`. On subsequent publishes with no guardian decisions, a patch bump is applied.

### CLAUDE.md integration

The plugin's CLAUDE.md injects trigger instructions into every session:

- **Session start** — if `API_REGISTRY_REPO` is configured: infer the current service name from the project directory, `.pinky-swear/draft-spec.json`, or draft spec in context; sparse-clone the registry to `.pinky-swear/registry/`; if a published spec exists for the service, read it into context silently; clean up the clone. If `API_REGISTRY_REPO` is not set, skip silently. If it is set but the clone fails, warn the user once that contract checks are disabled for the session — do not block work
- **Brainstorming** — if no spec exists: invoke `api-spec-brainstorming` in parallel; if spec exists: invoke `api-change-guardian` when interface changes are proposed
- **writing-plans** — invoke `api-contract-check` before finalizing any plan that consumes another service; invoke `api-change-guardian` if the plan changes the current service's interface
- **subagent-driven-development** — invoke `api-change-guardian` when subagent code would alter a published interface
- **requesting-code-review** — invoke `api-contract-check` for consumer code; invoke `api-change-guardian` for producer code
- **finishing-a-development-branch** — invoke `api-spec-publish` if `.pinky-swear/draft-spec.json` exists or unresolved guardian decisions exist

### Error handling

| Situation | Behavior |
|---|---|
| Registry unreachable | Warn and skip validation (except `api-spec-publish`, which fails hard) |
| No spec registered for a dependency | Warn and proceed without validation |
| Pinned version missing from registry | Fail with message identifying missing version and repo URL |
| Unresolved deferred changes at publish time | Block publish, list unresolved decisions |
| `api-dependencies.json` missing | Prompt to create it inline |

### Testing

Tests are session transcripts verifying correct skill triggers and output:

- Producer: new service brainstorm produces a valid draft IDL
- Producer: change guardian correctly classifies minor/major/patch/deprecation changes
- Producer: publish commits correct file with correct version and commit message
- Consumer: contract check passes/fails against pinned version
- Consumer: update notification fires when newer compatible version exists
- Consumer: deprecated operation warning surfaces with message and sunset version
- Edge: registry unreachable — validation skipped, publish blocked
- Edge: missing `api-dependencies.json` — skill prompts to create it
- Edge: pinned version absent from registry — clear error message

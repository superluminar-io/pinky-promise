# API Contract Plugin Design

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

One JSON file per version, named by semver. The highest semver in a service directory is latest. Published versions are immutable — `api-spec-publish` never overwrites an existing file. All commits are automated; no human commits. Commit message format:

```
user-service: 1.1.0 (minor) — added getUsers operation
```

Skills clone the registry to a temp directory on demand. Shallow clone (`--depth 1`) for reads; full clone only when diffing history.

### IDL format

A single JSON file per service version.

```json
{
  "name": "user-service",
  "version": "1.2.0",
  "description": "Manages users and authentication",
  "operations": [
    {
      "name": "getUser",
      "kind": "operation",
      "input": {
        "userId": { "type": "string" }
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
  },
  "bindings": [
    {
      "protocol": "http-json-rest",
      "operations": {
        "getUser": { "method": "GET", "path": "/users/{userId}" }
      },
      "connection": { "url": "https://api.example.com/v1" }
    }
  ]
}
```

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

Primitives: `string`, `number`, `boolean`, `null`

```json
{ "type": "string" }
{ "type": "array", "items": { "type": "string" } }
{ "type": "User" }                              // reference to types map
{ "optional": true, "type": "string" }          // optional wrapper on any type
```

Named types (defined in `types` map): `object`, `enum`, `union`.

#### Bindings

Each binding maps the abstract interface to a transport and optionally declares connection properties. Multiple bindings per service are allowed (e.g., `http-json-rest` and `grpc`). The `connection` field is optional — omit when URLs vary by environment.

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
| Deprecate any member | minor |
| Change descriptions or connection properties | patch |

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

Triggered in parallel with superpowers brainstorming when a service has no published spec yet. Runs a focused sub-conversation to identify the public API surface: which operations to expose, inputs and outputs, event types, subscription streams. Produces a draft IDL JSON held in conversation context. The draft is not published until `api-spec-publish` runs.

#### `api-change-guardian`

Cross-cutting. Invoked whenever a proposed change in any stage would affect a published spec. Fetches the current published spec, compares it to the proposed state from conversation context, classifies the delta per the semver rules above, and prompts the user:

1. Proceed with the appropriate version bump
2. Find a backwards-compatible approach instead
3. Defer the decision

Deferred decisions are tracked and must be resolved before `api-spec-publish` runs.

#### `api-contract-check`

For consumers. Fetches the target service's spec at the pinned version and validates the current plan or implementation against it. Flags: missing required parameters, wrong types, calling undefined operations, missing error handling. Also reports whether a newer compatible version is available, including a summary of what was added.

#### `api-spec-publish`

Final step for producers. Takes the current draft IDL, resolves any deferred guardian decisions (blocking if unresolved), determines the new version number, clones the registry, writes the new versioned file, commits with a descriptive message, and pushes. If no draft exists, runs `api-spec-brainstorming` first. Fails hard if the registry is unreachable.

Version number is determined from the guardian decisions accumulated during the session: the highest classification across all resolved changes (major > minor > patch) sets the bump. If no guardian decisions exist (first publish), the version is `1.0.0`.

### CLAUDE.md integration

The plugin's CLAUDE.md injects trigger instructions into every session:

- **Session start** — if `API_REGISTRY_REPO` is configured and the service has a published spec, silently fetch it into context
- **Brainstorming** — if no spec exists: invoke `api-spec-brainstorming` in parallel; if spec exists: invoke `api-change-guardian` when interface changes are proposed
- **writing-plans** — invoke `api-contract-check` before finalizing any plan that consumes another service; invoke `api-change-guardian` if the plan changes the current service's interface
- **subagent-driven-development** — invoke `api-change-guardian` when subagent code would alter a published interface
- **requesting-code-review** — invoke `api-contract-check` for consumer code; invoke `api-change-guardian` for producer code
- **finishing-a-development-branch** — invoke `api-spec-publish` if a draft spec or unresolved guardian decisions exist

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

# Design: api-spec-import skill

## Goal

Allow developers to register external third-party API specs (OpenAPI, gRPC, GraphQL) in the pinky-swear registry so that `api-contract-check` can validate consumer code against those external interfaces — catching hallucinated parameters and incorrect types introduced by the coding agent.

Secondary goals enabled by having accurate external specs in the registry:
- **Client codegen**: generate type-safe client code for an external service directly from its registry entry
- **MCP server generation**: generate an MCP server that proxies an external service's operations as tools, letting AI agents call the service directly

## Invocation

User-invocable slash command:

```
/api-spec-import <source> [--full | --subset | --auto]
```

`<source>` is a URL or local file path. Mode flag is optional; default is `--auto`.

## Input formats

- OpenAPI 3.x (JSON or YAML)
- OpenAPI 2.x / Swagger (JSON or YAML)
- gRPC / Protocol Buffers (`.proto` file)
- GraphQL SDL

## Versioning model

The registry stores your **declared dependency**, not a mirror of the external API. The pinky-swear version key is managed independently of the external API's own version:

```
stripe-api/1.0.0.json   ← first import (subset of Stripe 3.1.0)
stripe-api/1.1.0.json   ← two operations added (minor bump)
stripe-api/2.0.0.json   ← one operation removed (major bump)
```

The external API version and source URL are stored as provenance metadata inside the IDL entry:

```json
{
  "name": "stripe-api",
  "version": "1.1.0",
  "_source": {
    "url": "https://api.stripe.com/openapi.json",
    "external_version": "3.1.0",
    "imported_at": "2026-06-01"
  },
  "operations": [ ... ]
}
```

**Version bump rules on re-import:**
- Operations or types added only → minor bump
- Operations removed or signatures changed → major bump
- Both additions and removals/changes in the same re-import → major bump (most-breaking change wins)
- Confirmed set identical to previous entry → patch bump (reason: "no functional changes")
- Description or metadata changes only → patch bump
- Claude proposes the bump level; the user can override before writing

## Conversion

Claude fetches the spec (via `curl` for URLs, reads directly for local files) and converts it to two outputs written separately to the registry — a contract file and a bindings file.

**Contract mapping:**

| Source format | Operations | Events | Types |
|---|---|---|---|
| OpenAPI 3.x/2.x | paths + HTTP methods | `webhooks` section | `$ref` schemas |
| gRPC proto | unary RPC methods | — | `message` types |
| gRPC proto (streaming) | server-streaming RPCs | client-streaming RPCs | `message` types |
| GraphQL SDL | queries + mutations | — | object types |
| GraphQL SDL | — | subscriptions → IDL subscriptions | object types |

**Bindings mapping:**

| Source format | protocol | operations | prefix | connection |
|---|---|---|---|---|
| OpenAPI 3.x/2.x | `http-json-rest` | method + path per operation | common path prefix if present | first `servers[].url` stripped of any path prefix |
| gRPC | `grpc` | rpc name per operation | — | first server address |
| GraphQL | `graphql` | — | — | first server URL |

Member names are converted to camelCase. Type names are converted to PascalCase. Service name is derived from `info.title` (OpenAPI) or package name (gRPC/GraphQL), converted to kebab-case.

Operation, event, and subscription `description` fields are populated from the source spec: OpenAPI `summary` (falling back to `description`), proto leading comments, GraphQL field descriptions.

The import skill writes two files to the registry:
- `services/<name>/<version>.json` — abstract contract (operations, events, subscriptions, types)
- `services/<name>/bindings.json` — protocol mappings and connection URLs

## Modes

### `--auto` (default)

Claude scans the current codebase for calls to the external service (imports, client instantiation, method calls) and proposes those operations as the import set.

- **First import**: shows proposed set, asks for confirmation before writing.
- **Re-import**: shows a diff — operations previously declared, newly detected in code, and operations that disappeared from the codebase — before writing anything.

### `--subset`

Claude presents the full operation list from the external spec with a selection dialog.

- **First import**: pre-selects operations detected in the codebase (same detection as `--auto`), then shows the selection dialog so the user can review and adjust.
- **Re-import**: pre-selects previously declared operations. The user edits the existing set.

### `--full`

Converts and writes all operations. No selection step.

- **Re-import**: overwrites the previous contract and bindings files with the converted outputs and proposes a semver bump based on what changed.

## CLAUDE.md integration

Three hook points:

**During brainstorming**: if the design mentions calling an external service and no registry entry exists for it, surface before the brainstorm concludes:
> "The design depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."

**During writing-plans**: same check — if a planned step calls an external service with no registry entry, block finalisation with the same suggestion.

**During api-contract-check**: if validation encounters a call to an unregistered external service, surface the import suggestion inline rather than silently passing.

## Error handling

| Failure | Behaviour |
|---|---|
| Spec URL unreachable | Report clearly, offer local file fallback |
| Format unrecognised | List supported formats and exit |
| Conversion produces invalid IDL | Show what failed, ask user to resolve type mapping ambiguity |
| Registry write fails (SSH/git error) | Leave converted IDL in context; report error; user can retry |

## Files changed

| File | Change |
|---|---|
| `skills/api-spec-import/SKILL.md` | New — slash command implementation |
| `CLAUDE.md` | Add three hook entries (brainstorming, writing-plans, contract-check) |
| `skills/api-contract-check/SKILL.md` | Add: surface import suggestion for unregistered external services |

No changes to `api-spec-brainstorming`, `api-change-guardian`, or `api-spec-publish`.

## Implementation notes

**Question style**: use `AskUserQuestion` only for questions with a small closed set of options (e.g. confirming the derived service name, choosing a mode). Ask open-ended questions — operation selection, version overrides — as plain text. Never force open-ended answers into the options list.

**Publish default bump**: on subsequent publishes with no guardian decisions recorded, a patch bump is applied to the current registry version (not "use the version already in the draft").

**binding-spec-extension**: the named-environments + auth type catalogue described in earlier drafts has been superseded by the simpler `connection` + `prefix` binding format in `docs/idl-reference.md`. No separate extension design is needed.

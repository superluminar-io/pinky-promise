---
name: api-spec-brainstorming
description: "ALWAYS invoke this alongside superpowers:brainstorming whenever a user is designing, building, or starting a service. Do not invoke one without the other. Captures the public API surface — operations, events, subscriptions, types, bindings — as a versioned spec. Required even when the prompt includes tech choices (language, cloud, framework)."
---

# API Spec Brainstorming

Define the public API surface of a service in parallel with the superpowers brainstorming skill.

## When invoked

- A new service is being brainstormed and has no published spec in the registry
- A major version bump is being planned and the new API is being designed from scratch

## How to ask questions

- Use `AskUserQuestion` **only** for questions with a small, closed set of options (2–4 choices), such as "Which protocol?" or "Streaming or unary?".
- Ask all open-ended questions — message shapes, field names, types, operation names — as plain text in your response. Do **not** force them into `AskUserQuestion`.

## What to do

Work through the questions below one at a time. Use the answers to build toward the draft IDL.

### 0. Check registry configuration

Read `.claude/settings.json` and the project `CLAUDE.md` for `API_REGISTRY_REPO`. If not found in either:
> "⚠️ pinky-swear: `API_REGISTRY_REPO` is not configured. The draft spec will be written locally but cannot be published to a registry or validated by consumers until you set this up. See `docs/registry-setup.md`."

Do not block — continue with the brainstorm.

### 0b. Check for external service dependencies

Scan the conversation context for any mention of calling an external service (a service not being built in this repo — e.g. Stripe, Twilio, a third-party API). For each one with no registry entry, surface this immediately before continuing:
> "The design depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."

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
- Ask: "When should a caller use this operation — and when should they prefer a different one?"

Use the answer to the last question as the `description` field. Write it from the caller's perspective. Drop anything the user identifies as internal.

### 3. Identify events

Ask:
> "Does [service-name] emit any events that other services would react to? (fire-and-forget — no response expected)"

For each event:
- Ask for the payload structure
- Ask: "What triggers this event, and what should a consumer do when it receives it?"

Use the answer as the `description` field.

If none, proceed.

### 4. Identify subscriptions

Ask:
> "Does [service-name] support any ongoing streams or subscriptions — where a caller receives repeated data over time?"

For each subscription:
- Ask for input (what the subscriber provides) and output (what they receive)
- Ask: "When should a caller subscribe to this rather than polling via an operation?"

Use the answer as the `description` field.

If none, proceed.

### 5. Extract shared types

Review all inputs, outputs, and payloads collected. Identify shapes that appear more than once or that are complex enough to name. Propose names for them (PascalCase).

State: "I'll define these as named types: [list]."

### 6. Ask about bindings

Ask:
> "How is [service-name] exposed? (e.g. HTTP JSON REST, gRPC, GraphQL, message queue)"

For each binding:
- Ask for the protocol-specific mapping of operations (e.g. HTTP method and path for REST, RPC name for gRPC)
- For gRPC: ask for the proto `package` name (e.g. `audit`) — this is required to construct the fully-qualified service path `/<package>.<service>/<rpc>`
- Ask: "Is there an optional path prefix? (e.g. `/v1`)" (HTTP only)
- Ask: "Is there a known connection URL or host?"
- Ask: "Does this service require authentication?" If yes, ask which type (`bearer`, `basic`, `api_key`, `oauth2`) and collect the protocol-specific fields (e.g. `tokenUrl` and `scopes` for oauth2, `in` and `name` for api_key). Do **not** ask for credential values — those are the consumer's concern.
- Ask: "Does this binding apply to all versions, or a specific major version? (e.g. `1.*`, `2.*`, or leave blank for all)"

Set `contractVersion` on the binding entry accordingly. Omit the field if the binding applies to all versions.

`prefix` and `connection` are optional.

### 7. Produce the draft contract and bindings

**Contract** — use this exact shape. `pinkySwearVersion: 1` always first. Version `1.0.0` for first-time specs; guardian-recorded major for redesigns. No bindings in this file.

```json
{
  "pinkySwearVersion": 1,
  "name": "kebab-case-service-name",
  "version": "1.0.0",
  "description": "optional",
  "operations": [
    { "name": "camelCase", "kind": "operation", "description": "caller-perspective", "input": { "fieldName": { "type": "string" } }, "output": { "type": "TypeName" } }
  ],
  "events": [
    { "name": "camelCase", "kind": "event", "description": "caller-perspective", "payload": { "type": "TypeName" } }
  ],
  "subscriptions": [
    { "name": "camelCase", "kind": "subscription", "description": "caller-perspective", "input": { "fieldName": { "type": "string" } }, "output": { "type": "TypeName" } }
  ],
  "types": {
    "PascalCase": { "kind": "object", "fields": { "id": { "type": "string" }, "optional": { "optional": true, "type": "number" } } },
    "MyEnum": { "kind": "enum", "values": ["a", "b"] },
    "MyUnion": { "kind": "union", "variants": [{ "type": "string" }, { "type": "number" }] }
  }
}
```

Inline type expressions: `{ "type": "string|number|boolean|null|TypeName" }`, `{ "type": "array", "items": { "type": "string" } }`, `{ "optional": true, "type": "string" }`. `object`, `enum`, `union` must be named types — never inline.

**Bindings** — use this exact shape. `pinkySwearVersion: 1` always first.

```json
{
  "pinkySwearVersion": 1,
  "service": "kebab-case-service-name",
  "bindings": [
    {
      "contractVersion": "1.*",
      "protocol": "http-json-rest",
      "prefix": "/v1",
      "operations": { "operationName": { "method": "GET", "path": "/resource/{id}" } },
      "events": { "eventName": { "method": "POST", "path": "/webhooks/event" } },
      "subscriptions": { "subName": { "path": "/resource/{id}/watch" } },
      "connection": {
        "url": "https://api.example.com",
        "auth": { "type": "oauth2", "flow": "client_credentials", "tokenUrl": "https://auth.example.com/token", "scopes": ["api:read"] }
      }
    },
    {
      "contractVersion": "1.*",
      "protocol": "grpc",
      "package": "proto_package",
      "service": "ProtoServiceName",
      "operations": { "operationName": { "rpc": "RpcName" } },
      "subscriptions": { "subName": { "rpc": "RpcName" } },
      "connection": { "host": "service.internal", "port": 443 }
    }
  ]
}
```

Auth types: `bearer` (consumer provides `token`), `basic` (`username`/`password`), `api_key` (add `"in": "header"`, `"name": "X-Key"`, consumer provides `key`), `oauth2` with `client_credentials` or `password` flow. Omit `auth` if none required.

State both explicitly:

> "Draft contract for [service-name]:
>
> ```json
> { ... }
> ```
>
> Draft bindings:
>
> ```json
> { ... }
> ```
>
> Both will be published when api-spec-publish is invoked."

Persist both to disk so they survive across sessions:

```bash
mkdir -p .pinky-swear
grep -qxF '.pinky-swear/registry/' .gitignore 2>/dev/null || echo '.pinky-swear/registry/' >> .gitignore
grep -qxF '.pinky-swear/credentials.json' .gitignore 2>/dev/null || echo '.pinky-swear/credentials.json' >> .gitignore
cat > .pinky-swear/draft-spec.json << 'SPEC'
<full contract JSON>
SPEC
cat > .pinky-swear/bindings.json << 'BINDINGS'
<full bindings JSON>
BINDINGS
```

Announce: "Draft contract and bindings written to `.pinky-swear/`. They will be published when the branch is finished."

## Validation rules to enforce

- No inline `enum`, `union`, or `object` — define them in the `types` map
- All type references in `input`/`output`/`payload` are either inline type expressions or names defined in `types`
- Member names are camelCase
- Type names are PascalCase
- Service name is kebab-case

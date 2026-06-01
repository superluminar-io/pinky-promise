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

Synthesize all answers into a valid IDL JSON following the format in `docs/idl-reference.md`. Use version `1.0.0` for first-time specs. If this is a major version redesign (invoked alongside a planned major bump), use the new major version number from the guardian-recorded decision (e.g. `2.0.0`).

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

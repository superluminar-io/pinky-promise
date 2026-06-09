# Roadmap

This file tracks planned and in-progress work. It is not a commitment — priorities shift. Open an issue or PR if you want to discuss or contribute to any of these.

---

## In progress

### MCP server generation (`feat/api-mcp-server`)

The `api-mcp-server` skill generates a runnable Node.js MCP server from a pinky-promise spec. Each operation in the spec becomes an MCP tool, with the operation's `description` field used as the tool description. The server proxies tool calls to the real HTTP service, making Claude itself a first-class consumer of any pinky-promise-managed API.

See the `feat/api-mcp-server` branch.

---

## Planned

### Improved auth handling

The current auth model is declarative: `bindings.json` describes the auth flow (type, token URL, scopes) and `credentials.json` maps env vars to protocol parameters. This works but leaves gaps:

- **Credential validation at session start** — detect missing or malformed credentials before they cause a confusing runtime error mid-plan
- **Credential acquisition guidance** — when credentials are missing, tell the user exactly what to set and where, based on the declared auth flow
- **MCP auth support** — OAuth 2.0 for MCP servers (spec in progress upstream); generate the auth configuration alongside the MCP server
- **Broader auth type coverage** — mTLS, OIDC, AWS SigV4, and other patterns common in internal platform APIs

### Consumer-side tooling improvements

- **Dependency drift detection** — warn when a pinned version is significantly behind the latest published version, not just when it is incompatible
- **Multi-service contract checks** — when a service consumes more than one downstream service, check all contracts in a single pass rather than per-call
- **Auto-update suggestions** — when a consumer is pinned to an older minor version, propose an upgrade path and show what changed

### Registry improvements

- **Private registry support over HTTPS** — today the registry requires SSH access; support token-authenticated HTTPS clones for environments where SSH is unavailable
- **Registry health check skill** — `/api-registry-status` that lists all published services, their versions, and flags stale or missing bindings
- **Monorepo layout** — allow multiple services to share a single repo, with per-service sub-paths rather than requiring one repo per service

### Async messaging and schema registry

The current IDL covers synchronous request/response (HTTP REST, gRPC) well but has no first-class model for async messaging. The pinky-promise registry already stores versioned, typed contracts — which is structurally what a schema registry does. The plan is to lean into that:

- **Topic and event contracts** — extend the IDL to declare message topics, routing keys, and payload schemas as part of the public API surface; producers publish these alongside HTTP/gRPC contracts
- **pinky-promise as schema registry** — for brokers without a native schema registry (ActiveMQ, RabbitMQ, custom transports), the git registry becomes the schema registry; consumers fetch and pin to a schema version the same way they pin to an API version today
- **Native schema registry integration** — for brokers that have one (Kafka + Confluent, AWS MSK + Glue), validate and sync pinky-promise types against the external registry at publish time rather than replacing it
- **Schema serialization code generation** — generate Avro schemas, JSON Schema, or Protobuf definitions from spec types so services don't hand-write serialization formats
- **Full compatibility within a major version** — within a given major version, all schema changes must be both backward-compatible (existing consumers can read messages written by the new schema) and forward-compatible (updated consumers can read messages written by the old schema); the guardian enforces this and blocks any change that breaks either direction; only a major version bump is allowed to relax the constraint
- **Breaking change detection for message schemas** — extend `api-change-guardian` to classify schema evolutions (backward, forward, full compatibility) and block incompatible changes before a message format is published

### Developer experience

- **Tests for all skills** — expand the existing test suite to cover all skills with headless Claude sessions against a local registry fixture
- **`/api-spec-migrate` skill** — reads registry files written by an older format version and rewrites them to the current format; proposed automatically on major version bumps

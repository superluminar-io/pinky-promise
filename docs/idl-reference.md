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

For gRPC bindings, a `service` field names the protobuf service:

```json
{
  "protocol": "grpc",
  "service": "UserService",
  "operations": {
    "getUser": { "rpc": "GetUser" }
  }
}
```

## Semver rules

| Change | Bump |
|---|---|
| Add operation, event, subscription, or optional field | minor |
| Remove or change any operation, event, subscription, or type | major |
| Add a required field to an existing type | major |
| Deprecate any member | minor |
| Change descriptions or connection properties | patch |

Major bumps have no constraints on shape — v2 is a clean slate with no obligations to v1.

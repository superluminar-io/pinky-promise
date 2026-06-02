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

## Semver rules

| Change | Bump |
|---|---|
| Add operation, event, subscription, or optional field | minor |
| Remove or change any operation, event, subscription, or type | major |
| Add a required field to an existing type | major |
| Deprecate any member | minor |
| Change descriptions | patch |

Major bumps have no constraints on shape — v2 is a clean slate with no obligations to v1.

Binding changes (paths, URLs, protocols) are not subject to semver — they are managed in `bindings.json` independently of the contract version.

## Registry layout

Each service has two files in the registry:

```
services/
  <name>/
    <version>.json    ← abstract contract (versioned)
    bindings.json     ← protocol mappings + connection URLs (not versioned)
```

The contract file contains `name`, `version`, and the abstract interface (`operations`, `events`, `subscriptions`, `types`). It never contains transport or connection details.

The bindings file is always the current deployment state. It is updated independently of the contract version — adding a new protocol, changing a URL, or restructuring paths does not require a semver bump.

## bindings.json

Sits alongside the contract files at `services/<name>/bindings.json`.

```json
{
  "service": "user-service",
  "bindings": [
    {
      "protocol": "http-json-rest",
      "prefix": "/v1",
      "operations": {
        "getUser": { "method": "GET", "path": "/users/{userId}" },
        "createUser": { "method": "POST", "path": "/users" }
      },
      "events": {
        "userCreated": { "method": "POST", "path": "/webhooks/user-created" }
      },
      "connection": { "url": "https://api.example.com" }
    },
    {
      "protocol": "grpc",
      "service": "UserService",
      "operations": {
        "getUser": { "rpc": "GetUser" },
        "createUser": { "rpc": "CreateUser" }
      },
      "subscriptions": {
        "watchUser": { "rpc": "WatchUser" }
      },
      "connection": { "host": "grpc.api.example.com", "port": 443 }
    }
  ]
}
```

| Field | Required | Description |
|---|---|---|
| `service` | yes | Service name, must match the contract file |
| `bindings` | yes | Array of transport bindings |
| `bindings[].protocol` | yes | Transport identifier (`http-json-rest`, `grpc`, `graphql`) |
| `bindings[].prefix` | no | Path prefix prepended to all operation paths (e.g. `/v1`) |
| `bindings[].operations` | no | Map of operation name → transport-specific config |
| `bindings[].events` | no | Map of event name → transport-specific config |
| `bindings[].subscriptions` | no | Map of subscription name → transport-specific config |
| `bindings[].connection` | no | Connection properties — URL, host, port, etc. |
| `bindings[].service` | no | gRPC only — protobuf service name |

The effective path for an HTTP operation is `prefix + path` (e.g. `/v1` + `/users/{userId}` → `/v1/users/{userId}`).

# IDL Reference

API specs are JSON files. One file per service version, stored in the registry as `services/<name>/<version>.json`.

## Top-level fields

| Field | Required | Description |
|---|---|---|
| `pinkyPromiseVersion` | yes | Format version — currently `1`. Skills warn and stop if they encounter a value higher than they support. |
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
  "description": "Fetch a user's full profile by ID. Use when you have a userId and need name, email, or status. Prefer this over listing when the ID is already known.",
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
  "description": "Emitted after a new user is successfully persisted. React to this to trigger welcome emails, audit logs, or downstream provisioning.",
  "payload": { "type": "User" }
}
```

### subscription

Ongoing stream. Consumer subscribes with `input`, receives repeated `output`.

```json
{
  "name": "watchUser",
  "kind": "subscription",
  "description": "Stream live updates for a specific user. Use when you need to react to profile or status changes in real time rather than polling.",
  "input": { "userId": { "type": "string" } },
  "output": { "type": "User" }
}
```

The `description` field is optional but strongly recommended. It is used verbatim as the MCP tool description when the service is exposed via an MCP server — it is the primary signal an AI agent uses to decide when and how to invoke the tool. Write it from the caller's perspective: what is this for, when should I call it, and when should I prefer something else?

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
      "package": "user",
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
| `pinkyPromiseVersion` | yes | Format version — currently `1`. Skills warn and stop if they encounter a value higher than they support. |
| `service` | yes | Service name, must match the contract file |
| `bindings` | yes | Array of transport bindings |
| `bindings[].protocol` | yes | Transport identifier (`http-json-rest`, `grpc`, `graphql`) |
| `bindings[].prefix` | no | Path prefix prepended to all operation paths (e.g. `/v1`) |
| `bindings[].operations` | no | Map of operation name → transport-specific config |
| `bindings[].events` | no | Map of event name → transport-specific config |
| `bindings[].subscriptions` | no | Map of subscription name → transport-specific config |
| `bindings[].connection` | no | Connection properties — URL, host, port, etc. |
| `bindings[].contractVersion` | no | Semver range this binding applies to: exact (`"1.5.0"`), major wildcard (`"1.*"`), or omitted to match all versions |
| `bindings[].service` | no | gRPC only — protobuf service name |
| `bindings[].package` | no | gRPC only — proto package name; combined with `service` to form the fully-qualified name `<package>.<service>` used in RPC paths |

### contractVersion matching

When a consumer is pinned to a specific version, the binding selected is the most specific match:

1. Exact version match (`"1.5.0"`) — highest priority
2. Major wildcard match (`"1.*"`) — matches any `1.x.y`
3. No `contractVersion` — matches all versions (fallback)

If multiple bindings match at the same specificity (e.g. two `"1.*"` entries for different protocols), all are used.

Example — v1 and v2 served from different endpoints:

```json
{
  "service": "user-service",
  "bindings": [
    {
      "contractVersion": "1.*",
      "protocol": "http-json-rest",
      "prefix": "/v1",
      "connection": { "url": "https://api.example.com" }
    },
    {
      "contractVersion": "2.*",
      "protocol": "http-json-rest",
      "prefix": "/v2",
      "connection": { "url": "https://api.example.com" }
    },
    {
      "contractVersion": "1.5.0",
      "protocol": "http-json-rest",
      "connection": { "url": "https://legacy.api.example.com" }
    }
  ]
}
```

The effective path for an HTTP operation is `prefix + path` (e.g. `/v1` + `/users/{userId}` → `/v1/users/{userId}`).

The effective gRPC path for an RPC is `/<package>.<service>/<rpc>` (e.g. package `user`, service `UserService`, rpc `GetUser` → `/user.UserService/GetUser`). If `package` is omitted, the path is `/<service>/<rpc>`.

### Auth

The producer declares the auth flow in `connection.auth`. This is a machine-readable specification — structured enough for a client or MCP server to execute the flow automatically. No prose, no external links. Credential values are never stored here; they come from the consumer's local `credentials.json` (see below).

| `type` | Producer fields | Consumer provides |
|---|---|---|
| `bearer` | — | `token` |
| `basic` | — | `username`, `password` |
| `api_key` | `in` (`header` or `query`), `name` (e.g. `X-API-Key`) | `key` |
| `oauth2` + `client_credentials` | `tokenUrl`, `scopes` | `client_id`, `client_secret` |
| `oauth2` + `password` | `tokenUrl`, `scopes` | `username`, `password` |

Examples:

```json
"auth": { "type": "bearer" }

"auth": { "type": "basic" }

"auth": { "type": "api_key", "in": "header", "name": "X-API-Key" }

"auth": {
  "type": "oauth2",
  "flow": "client_credentials",
  "tokenUrl": "https://auth.example.com/oauth/token",
  "scopes": ["api:read", "api:write"]
}

"auth": {
  "type": "oauth2",
  "flow": "password",
  "tokenUrl": "https://auth.example.com/oauth/token",
  "scopes": ["api:read"]
}
```

## credentials.json

Stored at `.pinky-promise/credentials.json` in the consumer's project. **Never committed — add `.pinky-promise/credentials.json` to `.gitignore`.** Provides the credential values for each consumed service. The consumer names their env vars however they like and maps them here.

```json
{
  "user-service": {
    "token": "${MY_TOKEN_VAR}"
  },
  "payment-service": {
    "client_id": "${PAYMENT_CLIENT_ID}",
    "client_secret": "${PAYMENT_CLIENT_SECRET}"
  },
  "analytics-service": {
    "key": "${ANALYTICS_KEY}"
  }
}
```

Each key under a service name corresponds to a parameter in the "Consumer provides" column above for that service's auth type. Values may be literal strings or `${ENV_VAR}` references expanded at runtime.

The `${...}` expansion is the consumer's responsibility — values come from shell environment, a `.env` file, a secrets manager, or any other mechanism the team uses. The producer never sees or controls the variable names.

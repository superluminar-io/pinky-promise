# pinky-swear

API contract enforcement for Claude Code. Keeps producer and consumer services in sync by hooking into every stage of the [superpowers](https://github.com/obra/superpowers) development workflow — brainstorming, planning, implementation, review, and branch completion.

## What it does

When you build a service that other services call, you make a promise about its interface. pinky-swear makes that promise explicit, versioned, and enforced:

- **Producers** define their public API surface during brainstorming and publish it to a shared registry when the branch is complete.
- **Consumers** pin to a specific version and get their implementation validated against the published spec at every code review.
- **Breaking changes** are caught before they're planned, not after they're deployed.

Everything lives in a git registry you control. No external services.

## How it works

Once installed, pinky-swear injects checks at six points in the superpowers workflow:

| Stage | What happens |
|---|---|
| **Session start** | Fetches the current service's published spec into context |
| **Brainstorming** | Defines the API surface (new service) or flags breaking changes (existing service) |
| **Writing plans** | Validates calls to other services before the plan is finalised |
| **Subagent development** | Blocks implementation tasks that would change a published interface |
| **Code review** | Checks consumer code against pinned specs; flags interface changes in producer code |
| **Branch completion** | Publishes the draft spec to the registry |

If `API_REGISTRY_REPO` is not set, all checks skip silently — pinky-swear never blocks work on unconfigured projects.

## Skills

| Skill | Trigger | What it does |
|---|---|---|
| `api-spec-brainstorming` | New service with no published spec | Elicits operations, types, events, subscriptions, and bindings; writes draft to `.pinky-swear/` |
| `api-change-guardian` | Proposed change to a published interface | Classifies the change (major/minor/patch), records the decision, blocks unresolved deferrals at publish time |
| `api-contract-check` | Consumer code or plan calls another service | Validates calls against the pinned spec; warns about missing credentials, deprecated usage, and available updates |
| `api-spec-publish` | Branch completion with a draft spec present | Resolves guardian decisions, bumps the version, pushes contract and bindings to the registry |
| `/api-spec-import` | Registering an external API (OpenAPI, gRPC, GraphQL) | Converts and imports an external spec into the registry so contract-check can validate calls against it |

## The spec format

Each service has two files in the registry:

```
services/
  user-service/
    1.0.0.json      ← abstract contract (versioned)
    bindings.json   ← protocol mappings + auth (not versioned)
```

**Contract file** — operations, events, subscriptions, types. No transport details.

```json
{
  "name": "user-service",
  "version": "1.0.0",
  "operations": [
    {
      "name": "getUser",
      "kind": "operation",
      "description": "Fetch a user by ID. Use when you have a userId and need their profile.",
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
        "email": { "type": "string" }
      }
    }
  }
}
```

**Bindings file** — how to reach the service, including auth flow and per-version endpoints.

```json
{
  "service": "user-service",
  "bindings": [
    {
      "contractVersion": "1.*",
      "protocol": "http-json-rest",
      "prefix": "/v1",
      "operations": {
        "getUser": { "method": "GET", "path": "/users/{userId}" }
      },
      "connection": {
        "url": "https://api.example.com",
        "auth": {
          "type": "oauth2",
          "flow": "client_credentials",
          "tokenUrl": "https://auth.example.com/token",
          "scopes": ["api:read"]
        }
      }
    }
  ]
}
```

The `description` field on operations, events, and subscriptions is used as the MCP tool description when the service is exposed via an MCP server — write it from the caller's perspective.

See [`docs/idl-reference.md`](docs/idl-reference.md) for the full schema including auth types, `contractVersion` matching, and the consumer-side `credentials.json` format.

## Getting started

**1. Install pinky-swear** (see [Installation](#installation))

**2. Create a registry**

```bash
mkdir api-registry && cd api-registry
git init
mkdir -p services && touch services/.gitkeep
git add services/ && git commit -m "chore: init registry"
git remote add origin git@github.com:yourorg/api-registry.git
git push -u origin main
```

**3. Configure the registry URL** in your project's `.claude/settings.json`:

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:yourorg/api-registry.git"
  }
}
```

**4. Start a brainstorm** — open a Claude Code session in a new service project and describe what you're building. pinky-swear will interleave API surface questions with the design discussion and write the draft spec to `.pinky-swear/`.

## Installation

pinky-swear requires the [superpowers](https://github.com/obra/superpowers) plugin.

```
/plugin install superpowers@claude-plugins-official
```

pinky-swear is not listed in the official Anthropic marketplace. Install it directly from GitHub:

### From GitHub (recommended)

Run these commands from your project directory:

```bash
claude plugin marketplace add git@github.com:superluminar-io/pinky-swear.git --scope project
claude plugin install pinky-swear@pinky-swear-local --scope project
```

To update after new releases:

```bash
claude plugin update pinky-swear@pinky-swear-local --scope project
```

### From a local checkout

If you have the repo checked out locally (e.g. for development or to work with a private fork):

```bash
git clone git@github.com:superluminar-io/pinky-swear.git
cd pinky-swear
./install-local.sh /path/to/your/project
```

To pick up changes after editing the plugin source:

```bash
./install-local.sh /path/to/your/project --update
```

## Configuration

Point pinky-swear at your registry by setting `API_REGISTRY_REPO` in `.claude/settings.json` (project-scoped, committed) or `.claude/settings.local.json` (gitignored, machine-local):

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:yourorg/api-registry.git"
  }
}
```

If `API_REGISTRY_REPO` is not set, all skills skip silently. If it is set but unreachable, Claude warns once at session start that contract checks are disabled.

### Consumer projects

Consumer projects declare which service versions they depend on in `api-dependencies.json` at the project root:

```json
{
  "user-service": "1.0.0",
  "payment-service": "2.1.0"
}
```

`api-contract-check` creates this file interactively on first run if it doesn't exist.

### Credentials

If a service requires authentication, add a `.pinky-swear/credentials.json` (gitignored) with your credential values:

```json
{
  "user-service": {
    "client_id": "${MY_CLIENT_ID}",
    "client_secret": "${MY_CLIENT_SECRET}"
  }
}
```

The producer's `bindings.json` declares the auth flow (type, token endpoint, scopes). Your `credentials.json` maps your own env vars to the standard protocol parameters. The producer has no say in your variable naming.

## Registry setup

See [`docs/registry-setup.md`](docs/registry-setup.md) for registry layout, commit format, and SSH access configuration.

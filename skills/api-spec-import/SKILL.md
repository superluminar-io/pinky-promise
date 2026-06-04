---
name: api-spec-import
description: "Import an external API spec (OpenAPI, gRPC, GraphQL) into the pinky-promise registry as a declared dependency. Typical triggers: '/api-spec-import <url>', 'import the stripe spec', 'register this external API', 'add twilio to the registry'."
argument-hint: <url-or-file> [--full|--subset|--auto]
---

# API Spec Import

Import an external API spec into the pinky-promise registry as a declared dependency, so `api-contract-check` can validate consumer code against it.

## When invoked

- User runs `/api-spec-import <source> [--full|--subset|--auto]`
- `<source>` is a URL or local file path to an OpenAPI 3.x/2.x (JSON/YAML), gRPC `.proto`, or GraphQL SDL file
- Mode defaults to `--auto` if not specified

## Steps

**Registry data comes exclusively from a fresh clone. Never search the local filesystem for existing registry entries — no `find`, no directory traversal, no reading `.json` files from the project tree. Only read registry data from `.pinky-promise/registry/` after a fresh clone.**

### 1. Announce

> "Running api-spec-import to register external API spec."

### 2. Resolve API_REGISTRY_REPO

Resolve API_REGISTRY_REPO — use the Read tool, no shell execution:
- Read `.claude/settings.json` → check `env.API_REGISTRY_REPO`
- Read project `CLAUDE.md` → line matching `API_REGISTRY_REPO=`

If not found in either, `$API_REGISTRY_REPO` may still be set in the session environment and will be used directly by the clone command below. Only stop if the clone itself fails.

### 3. Fetch the spec

If `<source>` is a URL:
```bash
curl -fsSL "<source>" -o /tmp/api-spec-import-source
```

If this fails:
> "Could not fetch spec from `<source>`. Check the URL is reachable or provide a local file path instead."

Stop.

If `<source>` is a local file path, read it directly with the Read tool.

### 4. Detect format

Check in order — the first match wins:

- JSON/YAML containing `"openapi":` or `openapi:` at the top level → OpenAPI 3.x
- JSON/YAML containing `"swagger":` or `swagger:` at the top level → OpenAPI 2.x (Swagger)
- Contains `syntax = "proto` → gRPC Protocol Buffers
- Contains `type Query`, `type Mutation`, or `schema {` → GraphQL SDL

If format cannot be determined:
> "Format not recognised. Supported: OpenAPI 3.x/2.x (JSON/YAML), gRPC .proto, GraphQL SDL."

Stop.

### 5. Derive service name and external version

**OpenAPI**: derive name from `info.title` converted to kebab-case (e.g. "Stripe API" → `stripe-api`). Take `info.version` as `external_version`.

**gRPC**: derive name from the proto `package` declaration converted to kebab-case. Ask the user for a version string if the proto does not declare one.

**GraphQL**: ask the user for both service name (kebab-case) and version string. If the user does not provide a version, use `"unknown"`.

Confirm with the user:
> "Service name: `<derived-name>`, external version: `<external-version>`. Press enter to confirm or provide corrections."

If the user provides corrections, use their values as-is without re-deriving. For gRPC and GraphQL where the user is asked directly, use their input verbatim.

### 6. Check for existing registry entry

Always fetch fresh — sparse-checkout to only this service (name confirmed in step 5):

```bash
rm -rf .pinky-promise/registry
git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-promise/registry
git -C .pinky-promise/registry sparse-checkout set "services/<service-name>"
```

If clone fails:
> "Registry unreachable or not configured (`API_REGISTRY_REPO` is not set, or the repo is inaccessible). Set `API_REGISTRY_REPO` in `.claude/settings.json` or project `CLAUDE.md` — see `docs/registry-setup.md`."

Stop.

**Note:** From this point on, if execution stops for any reason, run `rm -rf .pinky-promise/registry` before stopping.

```bash
ls .pinky-promise/registry/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

If a previous entry exists, read it:
```bash
cat .pinky-promise/registry/services/<service-name>/<latest-version>.json
```

Note the previously declared operations list — needed for re-import diff in step 8.

### 7. Convert to IDL

Convert the fetched spec to pinky-promise IDL JSON using the following mapping:

Produce two outputs — a contract and a bindings object — held in context until step 10.

**Contract mapping:**

| Format | → Operations | → Events | → Types |
|---|---|---|---|
| OpenAPI 3.x/2.x | paths + HTTP methods | webhooks section | $ref schemas |
| gRPC (unary RPC) | RPC methods | — | message types |
| gRPC (server-streaming) | server-streaming RPCs | — | message types |
| gRPC (client-streaming) | — | client-streaming RPCs | message types |
| GraphQL | queries + mutations | — | object types |
| GraphQL subscriptions | — | subscriptions → IDL subscriptions | object types |

**Bindings mapping:**

| Format | protocol | package | service | operations | prefix | connection |
|---|---|---|---|---|---|---|
| OpenAPI 3.x/2.x | `http-json-rest` | — | — | method + path per operation | common path prefix if present | first `servers[].url` stripped of any path prefix |
| gRPC | `grpc` | proto `package` declaration | proto `service` name | rpc name per operation | — | first server address |
| GraphQL | `graphql` | — | — | — | — | first server URL |

For gRPC, `package` is extracted from the `package <name>;` declaration at the top of the proto file. It is required — without it the client cannot construct the correct fully-qualified RPC path `/<package>.<service>/<rpc>`. If no package is declared in the proto, ask the user to provide one.

**Auth mapping** — populate `connection.auth` from the source spec's security scheme. Map to the closest pinky-promise auth type:

| Source | Mapped `auth` |
|---|---|
| OpenAPI `http` / `bearer` | `{ "type": "bearer" }` |
| OpenAPI `http` / `basic` | `{ "type": "basic" }` |
| OpenAPI `apiKey` | `{ "type": "api_key", "in": "<in>", "name": "<name>" }` |
| OpenAPI `oauth2` / `clientCredentials` | `{ "type": "oauth2", "flow": "client_credentials", "tokenUrl": "<tokenUrl>", "scopes": [...] }` |
| OpenAPI `oauth2` / `password` | `{ "type": "oauth2", "flow": "password", "tokenUrl": "<tokenUrl>", "scopes": [...] }` |
| gRPC (no standard auth) | omit `auth` |
| Unrecognised / `openIdConnect` | omit `auth`, note in step 11 |

Never populate credential values — only the auth flow structure. If no security scheme is declared in the source spec, omit `auth` entirely.

**Description mapping** — populate `description` on each operation, event, and subscription:

| Format | Source for `description` |
|---|---|
| OpenAPI 3.x/2.x | `summary` if present, otherwise `description`; strip HTML |
| gRPC | Leading comment block above the `rpc` declaration (lines starting with `//`) |
| GraphQL | Field description string |

If no source text is available for a member, omit `description` rather than generating one.

Naming rules:
- Member names (operation names, parameter names, field names): camelCase
- Type names: PascalCase
- Service name: kebab-case (already determined in step 5)

Do **not** write anything yet — hold both outputs in context.

### 8. Apply mode

**`--full`**

Use all converted operations. Proceed to step 9.

---

**`--auto`** (default)

Scan the current codebase for references to `<service-name>` or its client class:

Substitute the actual derived service name and its PascalCase client class name for `<service-name>`, `<ServiceNameClient>`, and `<ServiceName>Client` in the grep pattern before running.

```bash
grep -rE "<service-name>|<ServiceNameClient>|<ServiceName>Client" . \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  --include="*.py" --include="*.go" --include="*.java" \
  -l 2>/dev/null
```

Read the matched files. Identify which operation names from the converted IDL are referenced (method calls, string references, imports).

**First import:**
> "Detected these operations in your codebase: [list].
> Confirm to import with this set, or name operations to add/remove."

**Re-import:**
> "Previously declared: [previous list]
> Newly detected in codebase: [additions]
> No longer detected in codebase: [removals]
> Confirm to proceed, or name operations to add/remove."

Wait for confirmation before proceeding.

---

**`--subset`**

List all operations from the converted IDL.

**First import:** pre-select operations detected in the codebase (same scan as `--auto`).
**Re-import:** pre-select previously declared operations.

Present as a selection list:
> "Select operations to import (marked items are pre-selected):
>
> [x] createCharge
> [ ] updateCharge
> [x] retrieveCharge
> [x] listCharges
> ...
>
> Type operation names to toggle selection, or 'done' to confirm."

Wait for 'done' before proceeding.

If the user types 'cancel' or 'quit', stop and run `rm -rf .pinky-promise/registry`.

### 9. Determine pinky-promise version

**First import:** version is `1.0.0`.

**Re-import:** compare the confirmed operation set against the previous entry:
- Operations or types added only → minor bump (e.g. `1.0.0` → `1.1.0`)
- Operations removed or input/output signatures changed → major bump (e.g. `1.0.0` → `2.0.0`)
- Only description or metadata changes → patch bump (e.g. `1.0.0` → `1.0.1`)
- Confirmed set is identical to the previous entry → patch bump, reason: 'no functional changes'
- Operations or types both added AND removed/changed in the same re-import → major bump (the most-breaking change takes precedence)

Propose to user:
> "Proposed version: `<new-version>` (<bump-type> bump — <reason>). Press enter to confirm or type a different version."

### 10. Assemble and write the registry entry

Build the contract JSON:
```json
{
  "pinkyPromiseVersion": 1,
  "name": "<service-name>",
  "version": "<pinky-promise-version>",
  "_source": {
    "url": "<source>",
    "external_version": "<external-version>",
    "imported_at": "<today's date — use the currentDate context variable if available, otherwise run: date +%F>"
  },
  "operations": [ ...confirmed operations only... ],
  "events": [ ...confirmed events only... ],
  "subscriptions": [ ...confirmed subscriptions only... ],
  "types": { ...types referenced by confirmed members only... }
}
```

Omit `events`, `subscriptions`, or `types` keys if empty.

Build the bindings JSON:
```json
{
  "pinkyPromiseVersion": 1,
  "service": "<service-name>",
  "bindings": [ ...protocol mappings and connection from step 7... ]
}
```

Write both to the registry:
```bash
mkdir -p .pinky-promise/registry/services/<service-name>
```

Write the contract to `.pinky-promise/registry/services/<service-name>/<pinky-promise-version>.json`.

Write the bindings to `.pinky-promise/registry/services/<service-name>/bindings.json`.

```bash
git -C .pinky-promise/registry add services/<service-name>/<version>.json
git -C .pinky-promise/registry add services/<service-name>/bindings.json
git -C .pinky-promise/registry commit -m "<service-name>: <version> (first-import|re-import) — imported from <source>"
git -C .pinky-promise/registry push
rm -rf .pinky-promise/registry
```

Use `first-import` for first imports and `re-import` for subsequent ones.

If `git push` fails:
```bash
rm -rf .pinky-promise/registry
```
> "Registry write failed (git push error). The converted IDL is shown below — copy it and push manually."

Display the full JSON. Do not stop the session.

### 11. Confirm

> "Imported `<service-name>` v<pinky-promise-version> (external: <external-version>) into the registry. `api-contract-check` will now validate calls against this spec."

If the source spec declares an auth scheme that could not be mapped (e.g. `openIdConnect`):
> "Note: the auth scheme `<scheme>` could not be automatically mapped. Add an `auth` block to the binding entry in `.pinky-promise/bindings.json` and re-run `/api-spec-import` to republish — do not edit the registry directly as a re-import will overwrite it. See `docs/idl-reference.md` for supported auth types."

---
name: api-spec-import
description: "Import an external API spec (OpenAPI, gRPC, GraphQL) into the pinky-swear registry as a declared dependency. Typical triggers: '/api-spec-import <url>', 'import the stripe spec', 'register this external API', 'add twilio to the registry'."
argument-hint: <url-or-file> [--full|--subset|--auto]
---

# API Spec Import

Import an external API spec into the pinky-swear registry as a declared dependency, so `api-contract-check` can validate consumer code against it.

## When invoked

- User runs `/api-spec-import <source> [--full|--subset|--auto]`
- `<source>` is a URL or local file path to an OpenAPI 3.x/2.x (JSON/YAML), gRPC `.proto`, or GraphQL SDL file
- Mode defaults to `--auto` if not specified

## Steps

### 1. Announce

> "Running api-spec-import to register external API spec."

### 2. Resolve API_REGISTRY_REPO

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Set it in your project CLAUDE.md or .claude/settings.json. See docs/registry-setup.md."

Stop.

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

```bash
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-import
```

If clone fails:
> "Registry unreachable. Check your SSH key and API_REGISTRY_REPO value."

Stop.

**Note:** From this point on, if execution stops for any reason, run `rm -rf /tmp/api-registry-import` before stopping.

```bash
ls /tmp/api-registry-import/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

If a previous entry exists, read it:
```bash
cat /tmp/api-registry-import/services/<service-name>/<latest-version>.json
```

Note the previously declared operations list — needed for re-import diff in step 8.

### 7. Convert to IDL

Convert the fetched spec to pinky-swear IDL JSON using the following mapping:

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

| Format | protocol | operations | prefix | connection |
|---|---|---|---|---|
| OpenAPI 3.x/2.x | `http-json-rest` | method + path per operation | common path prefix if present | first `servers[].url` stripped of any path prefix |
| gRPC | `grpc` | rpc name per operation | — | first server address |
| GraphQL | `graphql` | — | — | first server URL |

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

If the user types 'cancel' or 'quit', stop and run `rm -rf /tmp/api-registry-import`.

### 9. Determine pinky-swear version

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
  "name": "<service-name>",
  "version": "<pinky-swear-version>",
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
  "service": "<service-name>",
  "bindings": [ ...protocol mappings and connection from step 7... ]
}
```

Write both to the registry:
```bash
mkdir -p /tmp/api-registry-import/services/<service-name>
```

Write the contract to `/tmp/api-registry-import/services/<service-name>/<pinky-swear-version>.json`.

Write the bindings to `/tmp/api-registry-import/services/<service-name>/bindings.json`.

```bash
git -C /tmp/api-registry-import add services/<service-name>/<version>.json
git -C /tmp/api-registry-import add services/<service-name>/bindings.json
git -C /tmp/api-registry-import commit -m "<service-name>: <version> (first-import|re-import) — imported from <source>"
git -C /tmp/api-registry-import push
rm -rf /tmp/api-registry-import
```

Use `first-import` for first imports and `re-import` for subsequent ones.

If `git push` fails:
```bash
rm -rf /tmp/api-registry-import
```
> "Registry write failed (git push error). The converted IDL is shown below — copy it and push manually."

Display the full JSON. Do not stop the session.

### 11. Confirm

> "Imported `<service-name>` v<pinky-swear-version> (external: <external-version>) into the registry. `api-contract-check` will now validate calls against this spec."

If any `auth` blocks are present and empty:
> "Note: `auth` blocks in bindings are empty. Edit the registry entry directly to add authentication configuration once the binding-spec-extension design is implemented."

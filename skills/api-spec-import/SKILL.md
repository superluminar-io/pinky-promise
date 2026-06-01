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

Inspect the content:
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

**GraphQL**: ask the user for both service name (kebab-case) and version string.

Confirm with the user:
> "Service name: `<derived-name>`, external version: `<external-version>`. Press enter to confirm or provide corrections."

### 6. Check for existing registry entry

```bash
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-import
```

If clone fails:
> "Registry unreachable. Check your SSH key and API_REGISTRY_REPO value."

Stop.

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

| Format | → Operations | → Events | → Types | → Bindings |
|---|---|---|---|---|
| OpenAPI 3.x/2.x | paths + HTTP methods | webhooks section | $ref schemas | http + environments from `servers` |
| gRPC (unary RPC) | RPC methods | — | message types | grpc + environments |
| gRPC (server-streaming) | server-streaming RPCs | — | message types | grpc + environments |
| gRPC (client-streaming) | — | client-streaming RPCs | message types | grpc + environments |
| GraphQL | queries + mutations | — | object types | graphql + environments |
| GraphQL subscriptions | — | subscriptions → IDL subscriptions | object types | graphql + environments |

Naming rules:
- Member names (operation names, parameter names, field names): camelCase
- Type names: PascalCase
- Service name: kebab-case (already determined in step 5)

Binding format — use named environments, populate `url` from the spec's server definitions, leave `auth` blocks empty:
```json
"bindings": [{
  "protocol": "<http|grpc|graphql>",
  "environments": {
    "<env-name>": {
      "url": "<server-url-from-spec>",
      "auth": {}
    }
  }
}]
```

If the source spec has only one server URL, use `"default"` as the environment name.

Do **not** write anything yet — hold the converted IDL in context.

### 8. Apply mode

**`--full`**

Use all converted operations. Proceed to step 9.

---

**`--auto`** (default)

Scan the current codebase for references to `<service-name>` or its client class:
```bash
grep -r "<service-name>\|<ServiceNameClient>\|<ServiceName>Client" . \
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

### 9. Determine pinky-swear version

**First import:** version is `1.0.0`.

**Re-import:** compare the confirmed operation set against the previous entry:
- Operations or types added only → minor bump (e.g. `1.0.0` → `1.1.0`)
- Operations removed or input/output signatures changed → major bump (e.g. `1.0.0` → `2.0.0`)
- Only description or metadata changes → patch bump (e.g. `1.0.0` → `1.0.1`)

Propose to user:
> "Proposed version: `<new-version>` (<bump-type> bump — <reason>). Press enter to confirm or type a different version."

### 10. Assemble and write the IDL entry

Build the final IDL JSON:
```json
{
  "name": "<service-name>",
  "version": "<pinky-swear-version>",
  "_source": {
    "url": "<source>",
    "external_version": "<external-version>",
    "imported_at": "<YYYY-MM-DD>"
  },
  "operations": [ ...confirmed operations only... ],
  "events": [ ...confirmed events only... ],
  "subscriptions": [ ...confirmed subscriptions only... ],
  "types": { ...types referenced by confirmed members only... },
  "bindings": [ ...with named environments, auth blocks empty... ]
}
```

Omit `events`, `subscriptions`, or `types` keys if empty.

Write to registry:
```bash
mkdir -p /tmp/api-registry-import/services/<service-name>
```

Write the JSON to `/tmp/api-registry-import/services/<service-name>/<pinky-swear-version>.json`.

```bash
cd /tmp/api-registry-import
git add services/<service-name>/<version>.json
git commit -m "<service-name>: <version> (import) — imported from <source>"
git push
cd -
rm -rf /tmp/api-registry-import
```

If `git push` fails:
> "Registry write failed (git push error). The converted IDL is shown below — copy it and push manually."

Display the full JSON. Do not stop the session.

### 11. Confirm

> "Imported `<service-name>` v<pinky-swear-version> (external: <external-version>) into the registry. `api-contract-check` will now validate calls against this spec."

If any `auth` blocks are present and empty:
> "Note: `auth` blocks in bindings are empty. Edit the registry entry directly to add authentication configuration once the binding-spec-extension design is implemented."

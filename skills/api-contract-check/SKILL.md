---
name: api-contract-check
description: "Invoke before finalizing any plan or code that calls another service's public API. Verifies the call matches the published interface contract. Typical triggers: 'this service calls X', 'integrate with Y', 'use Z's API', 'make a request to', code that imports or invokes an external service client."
---

# API Contract Check

Validate the current implementation or plan against published API specs.

## When invoked

- Before finalizing a plan that calls another service
- During code review of consumer code
- When implementing code that calls an external service

## What to do

**Specs come exclusively from the registry. Never read another service's code or files — no `find`, no reading from `..` or sibling directories, no inferring the API from `.go`, `.ts`, `.proto`, or any other source files. Only read from `/tmp/api-registry-check/` after a fresh clone.**

Announce: "Running api-contract-check to validate against published API specs."

### Step 1: Locate API_REGISTRY_REPO and clone

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Cannot run contract check. See docs/registry-setup.md."

Stop.

Always fetch fresh — remove any stale clone first:

```bash
rm -rf /tmp/api-registry-check
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-check
```

If clone fails:
> "Registry unreachable. Skipping contract check."

Stop.

### Step 2: Read api-dependencies.json

```bash
cat api-dependencies.json
```

If the file does not exist, prompt to create it:
> "No api-dependencies.json found. Which services does this project consume?"

List available services:
```bash
ls /tmp/api-registry-check/services/
```

For each service the user names, list available versions and ask which to pin:
```bash
ls /tmp/api-registry-check/services/<service-name>/ | sort -V
```

Write `api-dependencies.json` to the project root:
```json
{
  "<service-name>": "<pinned-version>"
}
```

Announce: "Created api-dependencies.json. Proceeding with contract check."

### Step 3: Fetch pinned specs and bindings

For each entry in `api-dependencies.json`:

First check whether the service exists in the registry at all:
```bash
ls /tmp/api-registry-check/services/<service-name>/ 2>/dev/null
```

If the service directory does not exist:
> "Warning: **[service-name]** has no entry in the registry. Run `/api-spec-import <url-to-spec>` to register it and enable contract checking. Skipping contract check for this service."

Continue to the next dependency.

If the service exists, read the pinned contract:
```bash
cat /tmp/api-registry-check/services/<service-name>/<pinned-version>.json
```

Also read the bindings if present:
```bash
cat /tmp/api-registry-check/services/<service-name>/bindings.json 2>/dev/null || true
```

Select the binding entries that apply to the pinned version using this priority order:
1. Exact `contractVersion` match (e.g. `"1.5.0"` for pinned version `1.5.0`)
2. Major wildcard match (e.g. `"1.*"` for any `1.x.y`)
3. Entries with no `contractVersion` (fallback)

Use only the selected entries for transport-level validation (HTTP paths, gRPC RPC names, connection URLs).

If the file does not exist:
> "Error: [service-name] version [pinned-version] not found in registry ([API_REGISTRY_REPO]). Check api-dependencies.json."

```bash
rm -rf /tmp/api-registry-check
```

Stop on this error.

### Step 4: Validate the implementation

For each pinned spec, check the current implementation or plan:

**Operations called:**
- Does each called operation exist in the spec?
- Do parameter names match exactly?
- Do parameter types match (string ≠ number, required ≠ optional)?
- Is the return type handled correctly?

**Events/subscriptions consumed:**
- Does each consumed event/subscription exist in the spec?
- Does the payload handling match the spec type?

Report each violation:
> "**[service-name]** — [member-name]: [description of violation]"

If no violations:
> "[service-name] v[pinned-version] — contract check passed."

### Step 5: Warn about deprecated usage

For each deprecated member in use:
> "Warning: **[service-name].[member-name]** is deprecated. [deprecated.message][. Sunset planned for v[deprecated.sunsetVersion] if present]."

### Step 6: Report available updates

For each pinned service, find the highest version within the same major:
```bash
MAJOR=$(echo "<pinned-version>" | cut -d. -f1)
ls /tmp/api-registry-check/services/<service-name>/ | sort -V | grep "^${MAJOR}\." | tail -1
```

If a newer compatible version exists:
> "Update available: **[service-name]** [pinned-version] → [latest-compatible]. New in [latest-compatible]: [list operations/events/subscriptions added since pinned-version, found by comparing the two spec files]."

### Clean up

```bash
rm -rf /tmp/api-registry-check
```

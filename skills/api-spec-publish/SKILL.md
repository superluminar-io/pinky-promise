---
name: api-spec-publish
description: "Publish a service's API spec to the registry. Invoke when finishing a branch that has a draft spec or unresolved guardian decisions."
---

# API Spec Publish

Publish a service's API spec to the registry.

## When invoked

- At `finishing-a-development-branch` when a draft spec or unresolved guardian decisions exist
- Manually when a producer wants to publish

## What to do

Announce: "Running api-spec-publish to publish the API spec to the registry."

### Step 1: Check for a draft spec

Look for a draft IDL JSON in the conversation context — produced by `api-spec-brainstorming` or accumulated through guardian-approved changes.

If no draft is present:
> "No draft spec found in context. Running api-spec-brainstorming first."

Invoke `api-spec-brainstorming`, then continue.

### Step 2: Check for unresolved deferred decisions

Scan the conversation for lines marked "Deferred:" from previous `api-change-guardian` runs.

If any exist:
> "Cannot publish: the following decisions must be resolved first:
> - [deferred decision 1]
> - [deferred decision 2]
>
> For each: proceed with the version bump, or find a backwards-compatible approach?"

Wait for each to be resolved before continuing.

### Step 3: Locate API_REGISTRY_REPO

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Cannot publish. See docs/registry-setup.md."

Stop.

Clone the registry (full clone — needed to push):
```bash
git clone "$API_REGISTRY_REPO" /tmp/api-registry-publish
```

If clone fails:
> "Registry unreachable. Cannot publish without registry access."

Stop.

### Step 4: Determine the version number

Check whether this service has been published before:
```bash
ls /tmp/api-registry-publish/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

**First publish:** No versions found → version is `1.0.0`.

**Subsequent publish:** Current version is the last result above. Apply the highest bump classification from all guardian decisions recorded in this session (major > minor > patch). If no guardian decisions were recorded, apply a patch bump to the current registry version.

Calculate the new semver:
- patch: increment third number (1.2.3 → 1.2.4)
- minor: increment second number, reset third (1.2.3 → 1.3.0)
- major: increment first number, reset second and third (1.2.3 → 2.0.0)

Confirm with the user:
> "Ready to publish [service-name] as [new-version] ([bump]). Confirm? (yes/no)"

Wait for confirmation before proceeding.

### Step 5: Write and publish

Update the `version` field in the draft spec to `<new-version>`.

Create the service directory if needed:
```bash
mkdir -p /tmp/api-registry-publish/services/<service-name>
```

Write the spec file:
```bash
cat > /tmp/api-registry-publish/services/<service-name>/<new-version>.json << 'SPEC'
<full draft spec JSON>
SPEC
```

Verify the file:
```bash
cat /tmp/api-registry-publish/services/<service-name>/<new-version>.json
```

Commit and push:
```bash
cd /tmp/api-registry-publish
git add services/<service-name>/<new-version>.json
git commit -m "<service-name>: <new-version> (<bump>) — <one-line summary>"
git push origin main
```

The summary describes the most significant change (e.g. "added listUsers operation", "removed deprecated getUser", "updated connection URL").

### Step 6: Announce and clean up

> "Published [service-name] v[new-version] to the registry."

```bash
rm -rf /tmp/api-registry-publish
```

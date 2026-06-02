---
name: api-spec-publish
description: "Invoke when completing a branch where the public API was defined or changed. Commits the draft public API definition to the registry. Typical triggers: branch completion, 'ready to merge', 'done with this feature', or when a draft public API or unresolved versioning decisions are in context."
---

# API Spec Publish

Publish a service's API spec to the registry.

## When invoked

- At `finishing-a-development-branch` when a draft spec or unresolved guardian decisions exist
- Manually when a producer wants to publish

## What to do

Announce: "Running api-spec-publish to publish the API spec to the registry."

### Step 1: Check for a draft spec and bindings

Check for `.pinky-swear/draft-spec.json`:

```bash
cat .pinky-swear/draft-spec.json 2>/dev/null
```

Check for `.pinky-swear/bindings.json`:

```bash
cat .pinky-swear/bindings.json 2>/dev/null
```

If `draft-spec.json` exists, use it as the contract. If `bindings.json` exists, use it as the bindings.

If neither file exists, look for a draft contract and bindings in the conversation context — produced by `api-spec-brainstorming` or accumulated through guardian-approved changes.

If no contract is found in either source:
> "No draft spec found. Running api-spec-brainstorming first."

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

Update the `version` field in the draft contract to `<new-version>`.

Create the service directory if needed:
```bash
mkdir -p /tmp/api-registry-publish/services/<service-name>
```

Write the contract file:
```bash
cat > /tmp/api-registry-publish/services/<service-name>/<new-version>.json << 'SPEC'
<full contract JSON — no bindings>
SPEC
```

If bindings are present, write `bindings.json` (always overwrites — not versioned):
```bash
cat > /tmp/api-registry-publish/services/<service-name>/bindings.json << 'BINDINGS'
<full bindings JSON>
BINDINGS
```

Commit and push:
```bash
cd /tmp/api-registry-publish
git add services/<service-name>/<new-version>.json
git add services/<service-name>/bindings.json 2>/dev/null || true
git commit -m "<service-name>: <new-version> (<bump>) — <one-line summary>"
git push origin main
```

The summary describes the most significant change (e.g. "added listUsers operation", "removed deprecated getUser").

### Step 6: Announce and clean up

> "Published [service-name] v[new-version] to the registry."

```bash
rm -rf /tmp/api-registry-publish
rm -f .pinky-swear/draft-spec.json .pinky-swear/bindings.json
```

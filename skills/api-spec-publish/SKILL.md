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

**Published specs come exclusively from the registry. Never search the local filesystem for existing specs — no `find`, no directory traversal, no reading `.json` files from the project tree. Only read registry data from `.pinky-swear/registry/` after a fresh clone.**

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

Resolve API_REGISTRY_REPO — use the Read tool, no shell execution:
- Read `.claude/settings.json` → check `env.API_REGISTRY_REPO`
- Read project `CLAUDE.md` → line matching `API_REGISTRY_REPO=`

If not found in either, `$API_REGISTRY_REPO` may still be set in the session environment and will be used directly by the clone command below. Only stop if the clone itself fails.

Clone with sparse-checkout to the current service only. Always fetch fresh:
```bash
rm -rf .pinky-swear/registry
git clone --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-swear/registry
git -C .pinky-swear/registry sparse-checkout set "services/<service-name>"
```

If clone fails:
> "Registry unreachable. Cannot publish without registry access."

Stop.

### Step 4: Determine the version number

Check whether this service has been published before:
```bash
ls .pinky-swear/registry/services/<service-name>/ 2>/dev/null | sort -V | tail -1
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
mkdir -p .pinky-swear/registry/services/<service-name>
```

Write the contract file (always include `pinkySwearVersion: 1`):
```bash
cat > .pinky-swear/registry/services/<service-name>/<new-version>.json << 'SPEC'
<full contract JSON — no bindings, pinkySwearVersion: 1 at top level>
SPEC
```

If bindings are present, update `bindings.json`:

- **Minor or patch bump**: overwrite `bindings.json` with the draft bindings.
- **Major bump**: read the existing `bindings.json` from the registry, keep all entries whose `contractVersion` does not match the new major, then append the new major's entries. This preserves reachability of older versions.

  Ask the user: "This is a major bump to [new-version]. The new binding will be added for `[new-major].*`. Clients on v[old-major] will continue using the existing binding. Confirm?"

```bash
cat > .pinky-swear/registry/services/<service-name>/bindings.json << 'BINDINGS'
<full merged bindings JSON — pinkySwearVersion: 1 at top level>
BINDINGS
```

Commit and push:
```bash
cd .pinky-swear/registry
git add services/<service-name>/<new-version>.json
git add services/<service-name>/bindings.json 2>/dev/null || true
git commit -m "<service-name>: <new-version> (<bump>) — <one-line summary>"
git push origin main
```

The summary describes the most significant change (e.g. "added listUsers operation", "removed deprecated getUser").

### Step 6: Announce and clean up

> "Published [service-name] v[new-version] to the registry."

```bash
rm -rf .pinky-swear/registry
rm -f .pinky-swear/draft-spec.json .pinky-swear/bindings.json
```

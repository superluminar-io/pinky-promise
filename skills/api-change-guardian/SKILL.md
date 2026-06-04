---
name: api-change-guardian
description: "Invoke before adopting any design or plan that modifies a service's published public API — operations added, removed, or renamed; inputs or outputs changed. Typical triggers: 'remove this endpoint', 'rename this operation', 'change the response shape', 'change the parameter type to string', 'breaking change', 'simplify the API', 'the interface should look different'."
---

# API Change Guardian

Detect changes to a published API spec and force a conscious versioning decision.

## When invoked

Any stage (brainstorming, planning, implementation, review) proposes a change that would affect the public API surface of a service with a published spec.

## What to do

**Specs come exclusively from the registry. Never search the local filesystem — no `find`, no directory traversal, no reading `.json` files from the project tree. Only read from `.pinky-swear/registry/` after a fresh clone.**

Announce: "Running api-change-guardian to check for API contract changes."

### Step 1: Identify the service

Infer the service name from the draft spec in context or the project directory name. If ambiguous, ask.

### Step 2: Locate API_REGISTRY_REPO

Resolve API_REGISTRY_REPO — use the Read tool, no shell execution:
- Read `.claude/settings.json` → check `env.API_REGISTRY_REPO`
- Read project `CLAUDE.md` → line matching `API_REGISTRY_REPO=`

If not found in either, `$API_REGISTRY_REPO` may still be set in the session environment and will be used directly by the clone command below. Only stop if the clone itself fails.

### Step 3: Clone the registry

Always fetch fresh — sparse-checkout to only the current service:

```bash
rm -rf .pinky-swear/registry
git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-swear/registry
git -C .pinky-swear/registry sparse-checkout set "services/<service-name>"
```

If clone fails:
> "Registry unreachable (clone failed). Skipping contract check. Work can continue — changes are unvalidated."

Stop.

### Step 4: Find the current published spec

```bash
ls .pinky-swear/registry/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

If no versions exist, this is a new service — no published contract to check.

```bash
rm -rf .pinky-swear/registry
```

Stop.

Read the spec:
```bash
cat .pinky-swear/registry/services/<service-name>/<current-version>.json
```

Check `pinkySwearVersion`. If it is higher than `1`:
> "This registry entry was written by a newer version of pinky-swear (format version [n]). Update the plugin before proceeding."

Stop.

### Step 5: Identify proposed changes

From the conversation context, determine exactly what is changing:
- Which operations/events/subscriptions are being added, removed, or changed
- Which types are being added, removed, or changed
- Which member descriptions are changing

If only connection URLs, paths, or protocols are changing, these are binding changes — they belong in `bindings.json` and are not subject to semver. Stop and inform the user:
> "This change only affects bindings (connection URLs, paths, or protocols). Update `bindings.json` directly — no contract version bump needed."

List each contract change explicitly before classifying.

### Step 6: Classify

Apply these rules to each change:

| Change | Classification |
|---|---|
| Remove or change an existing operation, event, subscription, or type | **major** |
| Add a required field to an existing type | **major** |
| Add a new operation, event, or subscription | **minor** |
| Add an optional field to an existing type | **minor** |
| Deprecate a member | **minor** |
| Change a description | **patch** |

The overall classification is the highest across all individual changes (major > minor > patch).

Calculate the new version by applying the bump to `<current-version>`.

### Step 7: Prompt the user

> "This change is a **[major/minor/patch]** change to [service-name] (currently [current-version]).
>
> Changes detected:
> - [change 1]
> - [change 2]
>
> How would you like to proceed?
> 1. Proceed — bump to [new-version] when publishing
> 2. Find a backwards-compatible approach instead
> 3. Defer this decision"

### Step 8: Record the decision

**If proceeding:**
> "Recorded: [service-name] will bump to [new-version] ([major/minor/patch]) when published."

**If finding backwards-compatible approach:**
> "Understood. Let's find an approach that doesn't require a [major/minor] bump."
Collaborate on the alternative before continuing.

**If deferring:**
> "Deferred: [description of change]. This must be resolved before api-spec-publish runs."

Accumulate deferred decisions across multiple guardian runs in the same session. The final version bump at publish time is the highest classification across all resolved decisions.

### Clean up

```bash
rm -rf .pinky-swear/registry
```

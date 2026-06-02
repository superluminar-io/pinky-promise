---
name: api-change-guardian
description: "Invoke before adopting any design or plan that modifies a service's published public API — operations added, removed, or renamed; inputs or outputs changed. Typical triggers: 'remove this endpoint', 'rename this operation', 'change the response shape', 'change the parameter type to string', 'breaking change', 'simplify the API', 'the interface should look different'."
---

# API Change Guardian

Detect changes to a published API spec and force a conscious versioning decision.

## When invoked

Any stage (brainstorming, planning, implementation, review) proposes a change that would affect the public API surface of a service with a published spec.

## What to do

Announce: "Running api-change-guardian to check for API contract changes."

### Step 1: Identify the service

Infer the service name from the draft spec in context or the project directory name. If ambiguous, ask.

### Step 2: Locate API_REGISTRY_REPO

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Skipping contract check. See docs/registry-setup.md."

Stop.

### Step 3: Clone the registry

Always fetch fresh — remove any stale clone first:

```bash
rm -rf /tmp/api-registry-check
git clone --depth 1 "$API_REGISTRY_REPO" /tmp/api-registry-check
```

If clone fails:
> "Registry unreachable (clone failed). Skipping contract check. Work can continue — changes are unvalidated."

Stop.

### Step 4: Find the current published spec

```bash
ls /tmp/api-registry-check/services/<service-name>/ 2>/dev/null | sort -V | tail -1
```

If no versions exist, this is a new service — no published contract to check.

```bash
rm -rf /tmp/api-registry-check
```

Stop.

Read the spec:
```bash
cat /tmp/api-registry-check/services/<service-name>/<current-version>.json
```

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
rm -rf /tmp/api-registry-check
```

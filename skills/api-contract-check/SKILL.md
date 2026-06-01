---
name: api-contract-check
description: "Validate the current implementation or plan against published API specs. Invoke when writing plans that call another service, or when reviewing consumer code."
---

# API Contract Check

Validate the current implementation or plan against published API specs.

## When invoked

- Before finalizing a plan that calls another service
- During code review of consumer code
- When implementing code that calls an external service

## What to do

Announce: "Running api-contract-check to validate against published API specs."

### Step 1: Locate API_REGISTRY_REPO and clone

Check in order:
1. `echo $API_REGISTRY_REPO`
2. Grep project CLAUDE.md for `API_REGISTRY_REPO=`
3. Read `.claude/settings.json` for `API_REGISTRY_REPO`

If not found:
> "API_REGISTRY_REPO is not configured. Cannot run contract check. See docs/registry-setup.md."

Stop.

```bash
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

### Step 3: Fetch pinned specs

For each entry in `api-dependencies.json`:

First check whether the service exists in the registry at all:
```bash
ls /tmp/api-registry-check/services/<service-name>/ 2>/dev/null
```

If the service directory does not exist:
> "Warning: [service-name] has no published spec in the registry. Skipping contract check for this service."

Continue to the next dependency.

If the service exists, check for the pinned version:
```bash
cat /tmp/api-registry-check/services/<service-name>/<pinned-version>.json
```

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

# pinky-swear

This plugin manages API contracts between producer and consumer services. It integrates with the superpowers development workflow.

**Requires superpowers to be installed and active.**

## Registry is the only source of truth for API contracts

**NEVER** read another service's code, spec files, or any other files outside the current project to infer its API. This means:

- No `find`, no directory traversal, no reading files from `..`, `~`, or any path outside the current working directory
- No reading `.json`, `.proto`, `.yaml`, `.go`, `.ts`, or any other file from a sibling service directory to infer what that service provides
- No assumptions based on what happens to be checked out locally

When implementing a client or validating a consumer, the **only** permitted source of truth for what another service provides is its published spec in the registry — fetched via a fresh `git clone` of `API_REGISTRY_REPO` into `.pinky-swear/registry/`. If the registry is unreachable or has no entry for the service, say so and stop.

## Configuration

Set the registry URL in this project's CLAUDE.md (below this file's content) or in `.claude/settings.json`:

```
API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
```

If `API_REGISTRY_REPO` is not set, all skills warn and skip silently — they never block work.

## Session start

If `API_REGISTRY_REPO` is configured:
1. Identify the current service name (from project directory, `.pinky-swear/draft-spec.json`, or draft spec in context)
2. Fetch the registry fresh — always clone from `API_REGISTRY_REPO`, never read from local service directories:
   ```bash
   rm -rf .pinky-swear/registry
   git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-swear/registry 2>/dev/null
   git -C .pinky-swear/registry sparse-checkout set "services/<service-name>" 2>/dev/null
   ls .pinky-swear/registry/services/<service-name>/ 2>/dev/null | sort -V | tail -1
   ```
3. If a spec version is found, read it into context silently:
   ```bash
   cat .pinky-swear/registry/services/<service-name>/<latest-version>.json
   rm -rf .pinky-swear/registry
   ```
   Do not announce this to the user when it succeeds. If the clone fails, clean up and warn the user once:
   > "⚠️ pinky-swear: could not reach the API registry (`$API_REGISTRY_REPO`). Contract checks and the change guardian are disabled for this session. Check your SSH key and network access."

   Do not block the session — continue without registry data, but make sure the user knows the safety net is off.

## During brainstorming (superpowers brainstorming skill)

- If the current service has **no published spec**: you MUST invoke `api-spec-brainstorming` as part of the brainstorming session, interleaving its questions with the design brainstorm rather than treating them as two separate sequential conversations.
- If the current service **has a published spec** and the brainstorm proposes changes to the public interface: you MUST invoke `api-change-guardian` before those changes are adopted into the design.
- If the brainstorm mentions **calling an external service** (a service not developed in this repo) and no registry entry exists for it: you MUST surface this before the brainstorm concludes:
  > "The design depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."

## During writing-plans (superpowers writing-plans skill)

- If the plan involves **calling another service**: you MUST invoke `api-contract-check` before the plan is finalized.
- If the plan proposes **changes to the current service's public interface**: you MUST invoke `api-change-guardian` before the plan is finalized.
- If the plan involves **calling an external service** with no registry entry: you MUST surface this before the plan is finalized:
  > "The plan depends on `<external-service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before finalizing this plan."

## During subagent-driven-development (superpowers subagent-driven-development skill)

- If a subagent's proposed implementation would **change a published interface**: you MUST invoke `api-change-guardian` before approving that task's output.

## During requesting-code-review (superpowers requesting-code-review skill)

- For **consumer code** (code that calls another service): you MUST invoke `api-contract-check` as part of the review.
- For **producer code** (code that implements a service interface): you MUST invoke `api-change-guardian` as part of the review.

## During finishing-a-development-branch (superpowers finishing-a-development-branch skill)

- If `.pinky-swear/draft-spec.json` exists OR **unresolved guardian decisions** exist: you MUST invoke `api-spec-publish` before completing the branch.

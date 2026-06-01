# claude-api-plugin

This plugin manages API contracts between producer and consumer services. It integrates with the superpowers development workflow.

**Requires superpowers to be installed and active.**

## Configuration

Set the registry URL in this project's CLAUDE.md (below this file's content) or in `.claude/settings.json`:

```
API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
```

If `API_REGISTRY_REPO` is not set, all skills warn and skip silently — they never block work.

## Session start

If `API_REGISTRY_REPO` is configured:
1. Identify the current service name (from project directory or draft spec in context)
2. Check if a spec exists in the registry for this service
3. If yes, read it into context silently — do not announce this to the user

## During brainstorming (superpowers brainstorming skill)

- If the current service has **no published spec**: you MUST invoke `api-spec-brainstorming` in parallel with the brainstorm. Run both concurrently — do not wait for one to finish before starting the other.
- If the current service **has a published spec** and the brainstorm proposes changes to the public interface: you MUST invoke `api-change-guardian` before those changes are adopted into the design.

## During writing-plans (superpowers writing-plans skill)

- If the plan involves **calling another service**: you MUST invoke `api-contract-check` before the plan is finalized.
- If the plan proposes **changes to the current service's public interface**: you MUST invoke `api-change-guardian` before the plan is finalized.

## During subagent-driven-development (superpowers subagent-driven-development skill)

- If a subagent's proposed implementation would **change a published interface**: you MUST invoke `api-change-guardian` before approving that task's output.

## During requesting-code-review (superpowers requesting-code-review skill)

- For **consumer code** (code that calls another service): you MUST invoke `api-contract-check` as part of the review.
- For **producer code** (code that implements a service interface): you MUST invoke `api-change-guardian` as part of the review.

## During finishing-a-development-branch (superpowers finishing-a-development-branch skill)

- If a **draft spec** is present in context OR **unresolved guardian decisions** exist: you MUST invoke `api-spec-publish` before completing the branch.

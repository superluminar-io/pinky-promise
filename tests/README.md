# Tests

Tests are split into two tiers, run via `make`:

```bash
make test        # fast qualitative tests (~3-5 min)
make slow-test   # fast tests + full integration scenarios (~20-30 min)
```

## Requirements

- Claude Code CLI in PATH (`claude --version`)
- `python3` in PATH

## Structure

```
tests/
  Makefile                          ← test runner (at repo root)
  check-plugin-loaded.sh            ← sanity check: plugin loads correctly
  claude-code/                      ← fast qualitative tests
    test-helpers.sh                 ← shared run_claude / assert helpers
    test-*.sh                       ← one file per skill behaviour tested
    run-all.sh                      ← runs all fast tests, aggregates results
  notify-service/                   ← integration scenario: producer+consumer service
    prompts/
      initial-brainstorm.txt        ← triggers api-spec-brainstorming
      brainstorm-with-external.txt  ← triggers import suggestion for Twilio
    run-test.sh                     ← api-spec-brainstorming trigger
    run-brainstorm-with-external.sh ← external service import suggestion
  import-external-spec/             ← integration scenario: external spec import
    fixtures/
      echo-service.proto            ← gRPC fixture for format detection test
    prompts/
      import-openapi.txt            ← /api-spec-import with Petstore OpenAPI URL
      import-grpc.txt               ← /api-spec-import with local .proto fixture
    run-test.sh                     ← OpenAPI import skill execution
    run-grpc-import.sh              ← gRPC format detection + service name derivation
```

## Fast tests (`make test`)

Qualitative checks that ask Claude questions about the loaded skills and assert on the answers. Each test takes ~15–30 seconds.

| Test file | What it checks |
|---|---|
| `test-api-contract-check-import-hint` | api-contract-check surfaces `/api-spec-import` for unknown services |
| `test-api-spec-import-modes` | --auto shows diff, --subset pre-selects, --full skips selection on re-import |
| `test-api-spec-import-version-bump` | semver bump rules including tie-break (add+remove → major wins) |
| `test-api-spec-brainstorming` | contract has pinkySwearVersion first; no bindings in contract; bindings go to separate file; draft persisted to .pinky-swear/; object/enum/union must be named types |
| `test-api-change-guardian-triggers` | guardian fires on type changes, removals, response shape changes; not internal refactors |
| `test-brainstorming-external-hook` | CLAUDE.md hooks surface import suggestion during brainstorming and planning |
| `test-api-spec-publish` | no draft → falls back to brainstorming; unresolved deferred decisions block publish; missing registry config stops cleanly; first publish uses 1.0.0; confirmation required before push |

## Integration scenarios (`make slow-test`)

Full headless Claude sessions exercising end-to-end skill behaviour.

### notify-service

A notification service that is simultaneously producer and consumer of its own API (dead-letter processor calls sendNotification — cron-driven, no recursion).

| Script | Asserts |
|---|---|
| `run-test.sh` | `api-spec-brainstorming` is invoked when brainstorming a service with no published spec |
| `run-brainstorm-with-external.sh` | Import suggestion surfaces when the brainstorm mentions calling the Twilio API |

### import-external-spec

External API spec import via `/api-spec-import` slash command.

| Script | Asserts |
|---|---|
| `run-test.sh` | Skill executes steps (format detection + service name derivation) for a public OpenAPI URL |
| `run-grpc-import.sh` | gRPC format detected, service name derived from proto package declaration |

### api-spec-publish-integration

Bare registry, no seed. Prompt provides a draft spec and pre-authorises the confirmation.

| Script | Asserts |
|---|---|
| `run-test.sh` | `services/user-service/1.0.0.json` exists in the bare registry after the session |

### api-change-guardian-integration

Bare registry seeded with `user-service/1.0.0.json`. Prompt proposes removing `createUser`.

| Script | Asserts |
|---|---|
| `run-test.sh` | `api-change-guardian` Skill tool invoked; result classifies change as major/breaking |

### api-contract-check-integration

Bare registry seeded with `user-service/1.0.0.json`. `api-dependencies.json` pre-created pinning `user-service@1.0.0`. Prompt reviews code that calls the non-existent `getUserByEmail` operation.

| Script | Asserts |
|---|---|
| `run-test.sh` | `api-contract-check` Skill tool invoked; result surfaces violation for `getUserByEmail` |

## Shared fixtures

`tests/fixtures/user-service-1.0.0.json` — a minimal user-service spec used by guardian and contract-check integration tests.

`tests/registry-helpers.sh` — `create_bare_registry` and `seed_registry_spec` bash functions used by all three registry-backed integration tests.

## Adding a new scenario

1. Create `tests/<scenario-name>/prompts/<prompt>.txt`
2. Create `tests/<scenario-name>/run-*.sh` (copy an existing runner as a template)
3. Make it executable: `chmod +x tests/<scenario-name>/run-*.sh`
4. Add the script to the `slow-test` target in `Makefile`
5. Document it in this README

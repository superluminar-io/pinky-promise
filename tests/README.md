# Tests

Integration tests that verify pinky-swear's skills trigger correctly in realistic service scenarios.

## Structure

```
tests/
  <scenario-name>/
    prompts/
      <prompt-name>.txt    ← prompt text fed to claude -p
    run-test.sh            ← runs the scenario and asserts skill invocations
```

One subdirectory per scenario. Each `run-test.sh` invokes Claude Code headlessly via `claude -p`, loads pinky-swear via `--plugin-dir`, and greps the stream-json output for expected `Skill` tool invocations.

## Requirements

- Claude Code CLI in PATH (`claude --version`)
- `jq` in PATH

## Running tests

```bash
# Run a single scenario
tests/notify-service/run-test.sh

# With verbose output
tests/notify-service/run-test.sh --verbose
```

## Scenarios

### notify-service

A notification service that is simultaneously a producer (public sendNotification / subscribeToDeliveryEvents API) and a consumer of its own API (dead-letter processor calls sendNotification to emit deliveryFailed system events — cron-driven, no recursion).

**Asserts:** `api-spec-brainstorming` is invoked when brainstorming a service with no published spec.

## Adding a new scenario

1. Create `tests/<scenario-name>/prompts/<prompt>.txt`
2. Create `tests/<scenario-name>/run-test.sh` (copy an existing one as a template)
3. Make it executable: `chmod +x tests/<scenario-name>/run-test.sh`
4. Add it to this README under Scenarios

# Design: notify-service test fixture

## Goal

Add a test scenario that exercises pinky-swear's brainstorming integration on a service that is simultaneously a producer and a consumer of its own API — without recursion.

## Service scenario

`notify-service` exposes a public API for sending and tracking notifications (producer) and has an internal dead-letter queue processor that calls its own `sendNotification` to emit system-level `delivery.failed` events (consumer). The processor runs on a cron schedule; it only emits `deliveryFailed` notifications, which are never retried — so there is no recursion.

### Operations

**Sync (request/response)**
- `sendNotification(recipientId, channel, payload)` → `deliveryId`
- `cancelNotification(deliveryId)` → `cancelled: bool`
- `getDeliveryStatus(deliveryId)` → `status, attempts, lastError`

**Async (event/subscription)**
- `subscribeToDeliveryEvents(recipientId)` — ongoing stream of delivery status changes
- `deliveryFailed` event — fire-and-forget, emitted by the dead-letter processor calling its own `sendNotification`

## Test structure

Mirrors the superpowers `tests/skill-triggering` pattern:

```
tests/
  notify-service/
    prompts/
      initial-brainstorm.txt    ← prompt text fed to claude -p
    run-test.sh                 ← invokes claude -p, asserts api-spec-brainstorming fires
  README.md
```

`run-test.sh` loads pinky-swear via `--plugin-dir`, runs the prompt headlessly with `--max-turns 3`, and greps the stream-json output for a `Skill` tool invocation with `"skill":"api-spec-brainstorming"`.

## Skills exercised

| Skill | Trigger |
|---|---|
| `api-spec-brainstorming` | No spec exists → brainstorming session must define one |
| `api-contract-check` | Service calls itself → consumer contract must be checked |

## Non-goals

- No reference spec JSON for now — prompt + skill-trigger assertion is sufficient for a first fixture.
- No multi-turn conversation simulation — a single prompt with `--max-turns 3` is enough to verify skill triggering.

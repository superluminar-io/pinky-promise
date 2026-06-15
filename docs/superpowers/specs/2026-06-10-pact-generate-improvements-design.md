# api-pact-generate improvements

**Date:** 2026-06-10
**Status:** approved

## Problem

The `api-pact-generate` skill always asks the user whether they want consumer or provider tests, even when the project state makes the answer obvious. It also uses the term "verification" where "validation" is more accurate, lacks guidance on a simpler provider self-validation pattern that requires no Pact Broker, and does not communicate the anti-hallucination guarantee that consumer tests provide.

## Scope

Four targeted edits to the existing skill. No structural changes to the step layout.

---

## 1. Role detection (Step 1)

The skill checks two things on startup: existing test files and role signals. No question is asked until the project state is understood.

### Existing test detection

- Consumer tests present: `pact_consumer_test.go` exists
- Provider tests present: `pact_provider_test.go` exists

### Role signals (used only when no tests exist)

- **Provider signal:** `.pinky-promise/draft-spec.json` exists
- **Consumer signal:** any `.pinky-promise/*.json` other than `draft-spec.json`, or `api-dependencies.json` exists

### Decision table

| Existing tests | Role signals | Behaviour |
|---|---|---|
| Consumer only | — | Multi-select: **Update consumer tests** / **Add provider tests** (if provider signal exists) |
| Provider only | — | Multi-select: **Update provider tests** / **Add consumer tests** (if consumer signal exists) |
| Both | — | Multi-select: **Update consumer tests** / **Update provider tests** |
| None | Consumer only | Announce detected role → generate consumer tests |
| None | Provider only | Announce detected role → generate provider tests |
| None | Both | Ask with note (multi-select): "pinky-promise detected both a draft spec and imported dependencies — which would you like to generate?" |
| None | Neither | Ask (multi-select, no context available) |

### Update flow

When updating existing tests: compare the current spec's operations against the operations covered in the existing test file, identified by function name convention (`TestPactConsumer_<OperationName>`, `TestPactProvider_<OperationName>`). For each delta — new operation in spec not yet in tests, changed input/output shape, operation removed from spec — propose the change individually and wait for approval before moving to the next. User can accept, skip, or edit each proposed change.

---

## 2. Terminology

Replace "verification" with "validation" in all user-facing text: announces, option labels, and generated comments. Pact-go library identifiers (`NewVerifier`, `VerifyProvider`, `VerifyRequest`) are unchanged — these are third-party API names.

---

## 3. Provider self-validation (Step 7)

When the provider path is taken, present a **multi-select** (both options can be chosen):

- **Self-validation** — generate spec-derived consumer tests to run in this pipeline. No Pact Broker needed. The spec is the contract.
- **Consumer pact validation** — generate `pact_provider_test.go` to pull and validate consumer-published pacts from a Pact Broker.

If both are selected: generate `pact_consumer_test.go` first (Steps 3–6), then generate `pact_provider_test.go`, then announce both run commands together.

**Why self-validation is sufficient in a pinky-promise shop:** the spec is the complete callable surface — nothing undocumented is reachable by consumers. Spec-derived consumer tests therefore cover exactly the contract boundary, with no Pact Broker or consumer coordination required.

---

## 4. Anti-hallucination framing

### In the Step 6 announce

After generating `pact_consumer_test.go`, explain: these tests are not just contract artifacts — they validate the client code against the spec. If the implementation accesses a field that doesn't exist in the spec, calls an undeclared path, or uses a wrong parameter name, the test fails. This is the anti-hallucination guarantee: the spec is the only source of truth, and the tests enforce it.

### In the generated test file

A comment block at the top of `pact_consumer_test.go`:

```go
// These tests validate that this service's client code only uses operations and fields
// declared in <service>@<version>. Any field, parameter, or path not in the spec will
// cause a test failure — this is intentional. The spec is the contract; the tests
// enforce it.
```

---

## Version bump

Skill behaviour change (UX improvement + new update flow): **patch** bump — `0.0.1` → `0.0.2`.

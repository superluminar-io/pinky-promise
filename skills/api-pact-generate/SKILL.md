---
name: api-pact-generate
description: "Generate Pact consumer-driven contract tests from a pinky-promise spec. Typical triggers: '/api-pact-generate', 'generate pact tests', 'create contract tests', 'set up CDCT'."
argument-hint: [<service-name>] [--fix <pact-file>]
---

# API Pact Generate

Generate Pact consumer-driven contract test files from a pinky-promise spec.

## When invoked

- `--fix <pact-file>` — re-open the example review flow on an existing Pact JSON file without regenerating interactions
- No flag — generate a new Pact contract from the spec

## What to do

**Specs come exclusively from the registry or local draft files. Never read service implementation files.**

**pact-go provides its own mock server internally. Never invoke `api-mock-server` as part of Pact test generation — `api-mock-server` is a separate tool for standalone development mocks, not for CDCT.**

Announce: "Running api-pact-generate."

### Step 1: Detect role

Check the project state before asking anything:

```bash
# provider signal: this service publishes its own API
ls .pinky-promise/draft-spec.json 2>/dev/null >/dev/null && echo "HAS_DRAFT"
# consumer signal: any imported service spec (e.g. github-openapi.json, stripe-openapi.json)
find .pinky-promise -maxdepth 1 -name "*.json" ! -name "draft-spec.json" 2>/dev/null | grep -q . && echo "HAS_IMPORTS"
# consumer signal: pinned dependency declaration
ls api-dependencies.json 2>/dev/null >/dev/null && echo "HAS_DEPS"
ls pact_consumer_test.go 2>/dev/null >/dev/null && echo "HAS_CONSUMER_TESTS"
ls pact_provider_test.go 2>/dev/null >/dev/null && echo "HAS_PROVIDER_TESTS"
```

**Signals:**
- Provider signal: `HAS_DRAFT` — `.pinky-promise/draft-spec.json` exists (this service publishes an API)
- Consumer signal: `HAS_IMPORTS` or `HAS_DEPS` — **any** `.json` file in `.pinky-promise/` *other than* `draft-spec.json` is an imported external service spec that this project depends on as a consumer (examples: `.pinky-promise/github-openapi.json`, `.pinky-promise/stripe-openapi.json`, `.pinky-promise/bedrock-runtime-openapi.json`); `api-dependencies.json` also counts as a consumer signal
- Existing consumer tests: `HAS_CONSUMER_TESTS`
- Existing provider tests: `HAS_PROVIDER_TESTS`

**Decision table:**

| Existing tests | Role signals | Behaviour |
|---|---|---|
| Consumer only | Any | Multi-select: **Update consumer tests** / **Add provider tests** (show "Add provider tests" only if provider signal exists) |
| Provider only | Any | Multi-select: **Update provider tests** / **Add consumer tests** (show "Add consumer tests" only if consumer signal exists) |
| Both | Any | Multi-select: **Update consumer tests** / **Update provider tests** |
| None | Consumer only | Announce: "Detected consumer-only project — generating consumer tests." → proceed as Consumer |
| None | Provider only | Announce: "Detected provider-only project — generating provider tests." → proceed as Provider |
| None | Both | Ask (multi-select): "pinky-promise detected both a draft spec and imported service dependencies — which would you like to generate?" Options: **Consumer tests** / **Provider tests** |
| None | Neither | Ask (multi-select): "What would you like to generate?" Options: **Consumer tests** / **Provider tests** |

> **Example:** if `.pinky-promise/draft-spec.json` AND `.pinky-promise/github-openapi.json` both exist, that means `HAS_DRAFT` (provider signal) AND `HAS_IMPORTS` (consumer signal) are both present → use the "None | Both" row in the decision table → ask multi-select.

**Update flow** (when updating existing tests): compare the current spec's operations against the operations covered in the existing test file, identified by function name convention (`TestPactConsumer_<OperationName>`, `TestPactProvider_<OperationName>`). For each delta — new operation in spec not yet in tests, changed input/output shape, operation removed from spec — propose the change individually and wait for approval before moving to the next. User can accept, skip, or edit each proposed change.

### Step 2: Locate the spec

**Consumer:** Read `api-dependencies.json` for the pinned service version. Fetch from registry:
```bash
rm -rf .pinky-promise/registry
git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-promise/registry
git -C .pinky-promise/registry sparse-checkout set "services/<service-name>"
cat .pinky-promise/registry/services/<service-name>/<pinned-version>.json
cat .pinky-promise/registry/services/<service-name>/bindings.json 2>/dev/null || true
rm -rf .pinky-promise/registry
```

**Provider:** Check for `.pinky-promise/draft-spec.json`, else fetch the latest from the registry.

### Step 3: Ask about Pact setup (consumer only)

Use `AskUserQuestion` (single-select):
- **Create new Pact contract** — generate interactions for all operations
- **Add interactions to existing contract** — append to `pacts/<consumer>-<provider>.json`

Ask for the consumer service name (open text): "What is the name of this consumer service? (kebab-case)"

### Step 4: Generate interactions

For each operation in the spec, generate one Pact interaction:

```json
{
  "description": "<operation description from spec>",
  "request": {
    "method": "<HTTP method from bindings>",
    "path": "<effective path — prefix + path from bindings, with example values substituted>",
    "headers": { <auth headers if configured> },
    "body": <synthetic request body — see rules below>
  },
  "response": {
    "status": 200,
    "headers": { "Content-Type": "application/json" },
    "body": <synthetic response body — see rules below>
  }
}
```

**Synthetic example rules:**
- `string` → `"<field-name>-example"` (e.g. `userId` → `"userId-example"`)
- `number` → `1`
- `boolean` → `true`
- `array` → `[<single element of items type>]`
- `enum` → first listed value
- `object` (named type) → fill each field recursively using same rules
- `optional` fields → include them (better to test with than without)

For path parameters (e.g. `{userId}`): substitute the synthetic string value.

For auth: if `connection.auth` declares bearer or API key, include a placeholder header.

### Step 5: Review examples

Present all generated interactions as a single JSON block for review. These will be translated into pact-go test code in the next step.

Use `AskUserQuestion` (single-select):
- **Accept all** — proceed to generate Go test code
- **Edit** — I will paste corrected JSON

If Edit: wait for the user to paste corrected interactions JSON. Use their version as the basis for code generation.

### Step 6: Generate the consumer test file

Generate a Go test file `pact_consumer_test.go` that uses pact-go's own mock server to define interactions and record the contract. **Do NOT use the `api-mock-server` skill here — pact-go spins up its own mock server internally.**

```go
package <package>_test

import (
    "fmt"
    "net/http"
    "testing"

    "github.com/pact-foundation/pact-go/v2/consumer"
    "github.com/pact-foundation/pact-go/v2/matchers"
)

func TestPactConsumer_<OperationName>(t *testing.T) {
    mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
        Consumer: "<consumer-name>",
        Provider: "<service-name>",
        PactDir:  "./pacts",
    })
    if err != nil {
        t.Fatal(err)
    }

    err = mockProvider.
        AddInteraction().
        Given("<state description>").
        UponReceiving("<operation description from spec>").
        WithRequest(consumer.Request{
            Method:  "<HTTP method>",
            Path:    matchers.String("<effective path with example values>"),
            Headers: matchers.MapMatcher{
                // include auth header placeholder if configured
            },
            Body: matchers.Map{
                // request body fields using matchers.Like() for each field
                // e.g. "userId": matchers.Like("userId-example"),
            },
        }).
        WillRespondWith(consumer.Response{
            Status:  200,
            Headers: matchers.MapMatcher{"Content-Type": matchers.Like("application/json")},
            Body: matchers.Map{
                // response body fields using matchers.Like() for each field
            },
        }).
        ExecuteTest(t, func(config consumer.MockServerConfig) error {
            // Call your actual client code here against the pact mock server
            baseURL := fmt.Sprintf("http://%s:%d", config.Host, config.Port)
            resp, err := http.Get(baseURL + "<path>")
            if err != nil {
                return err
            }
            if resp.StatusCode != 200 {
                return fmt.Errorf("expected 200, got %d", resp.StatusCode)
            }
            return nil
        })
    if err != nil {
        t.Fatal(err)
    }
}
```

Generate one test function per operation from the confirmed interactions. Fill in:
- `matchers.Like(value)` for each field — pact-go verifies the type matches, not the exact value
- The `ExecuteTest` callback must call the **real client code** (or an `http.Get` stub) against `config.Host:config.Port` — this is what causes pact-go to record the interaction

Add to `go.mod` if not already present:
```
require github.com/pact-foundation/pact-go/v2 v2.x.x
```

Announce:
> "Generated `pact_consumer_test.go`. Running the tests will spin up pact-go's mock server, verify interactions, and write `pacts/<consumer>-<provider>.json` automatically:
> ```
> go test ./... -run TestPactConsumer
> ```
> See Pact Go docs: https://docs.pact.io/implementation_guides/go"

### Step 7: Provider verification setup (provider role only)

Generate a Go test file `pact_test.go` that sets up Pact provider verification:

```go
package main_test

import (
    "testing"
    "github.com/pact-foundation/pact-go/v2/provider"
)

func TestPactProvider(t *testing.T) {
    verifier := provider.NewVerifier()
    err := verifier.VerifyProvider(t, provider.VerifyRequest{
        ProviderBaseURL:            "http://localhost:8080",
        BrokerURL:                  "<PACT_BROKER_URL>",
        PublishVerificationResults: true,
        ProviderVersion:            "<version>",
        StateHandlers: provider.StateHandlers{
            // Add state handlers here for each provider state in your pacts
        },
    })
    if err != nil { t.Fatal(err) }
}
```

Announce:
> "Generated `pact_test.go`. Fill in `PACT_BROKER_URL` and state handlers, then run:
> ```
> go test ./... -run TestPactProvider
> ```"

## --fix mode

When invoked with `--fix <pact-file>`:
1. Read the existing Pact JSON file
2. Present all interactions for review (Step 5 above)
3. Wait for edits
4. Overwrite the file with the confirmed version

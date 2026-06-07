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

### Step 1: Determine role

Use `AskUserQuestion` (single-select):
- **Consumer** — I am writing a client that calls this service (generates consumer-side interaction file)
- **Provider** — I am implementing this service (generates provider verification setup)

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

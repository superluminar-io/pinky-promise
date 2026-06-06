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

Present all generated interactions as a single JSON block for review.

Use `AskUserQuestion` (single-select):
- **Accept all** — write as-is
- **Edit** — I will paste corrected JSON

If Edit: wait for the user to paste corrected interactions JSON. Use their version.

### Step 6: Write the Pact file

Write to `pacts/<consumer-name>-<provider-name>.json`:

```json
{
  "consumer": { "name": "<consumer-name>" },
  "provider": { "name": "<service-name>" },
  "interactions": [ <confirmed interactions> ],
  "metadata": {
    "pactSpecification": { "version": "2.0.0" },
    "pinkyPromise": { "specVersion": "<spec-version>", "generatedAt": "<date>" }
  }
}
```

Announce:
> "Written `pacts/<consumer>-<provider>.json`. Run provider verification with:
> ```
> go test ./... -run TestPactProvider
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

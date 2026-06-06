---
name: api-mock-server
description: "Generate a mock server or mock client from a pinky-promise API spec. Typical triggers: '/api-mock-server', 'generate a mock server', 'generate a mock client', 'stub out the server', 'I need something to test my server against'."
argument-hint: [<service-name>] [--server|--client] [--http|--grpc]
---

# API Mock Server / Mock Client

Generate a mock server (for consumer testing) or a mock client (for producer testing) from a pinky-promise spec.

## Modes

- **Mock server** (`--server`, default for consumers): simulates the provider — a fake implementation consumers test against
- **Mock client** (`--client`, default for producers): simulates the consumer — calls your server with example requests to verify it responds correctly

## When invoked

- Consumer building a client → generate mock server to test against
- Producer building a service → generate mock client to verify server behaviour
- Both roles → offer both

## What to do

**Specs come exclusively from the registry or `.pinky-promise/draft-spec.json`. Never read service implementation files.**

Announce: "Running api-mock-server."

### Step 1: Determine what to generate

If not specified by flag, use `AskUserQuestion` (multi-select):
- **Mock server** — fake implementation for consumers to test against (Prism for HTTP, Go stub for gRPC)
- **Mock client** — test harness that calls your server with example requests (Go test file)

### Step 2: Locate the spec

Check for `.pinky-promise/draft-spec.json` first:
```bash
cat .pinky-promise/draft-spec.json 2>/dev/null
```

If not found, resolve `API_REGISTRY_REPO` (Read tool: `.claude/settings.json` then project `CLAUDE.md`) and fetch from the registry:
```bash
rm -rf .pinky-promise/registry
git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-promise/registry
git -C .pinky-promise/registry sparse-checkout set "services/<service-name>"
cat .pinky-promise/registry/services/<service-name>/<latest-version>.json
cat .pinky-promise/registry/services/<service-name>/bindings.json 2>/dev/null || true
rm -rf .pinky-promise/registry
```

### Step 3: Determine protocols

Use `AskUserQuestion` (multi-select, if multiple protocols are in the bindings):
- Generate HTTP mock (Prism)
- Generate gRPC mock (Go stub)

### Step 3a: HTTP mock (Prism)

Convert the spec to OpenAPI 3.x and write to `api-mock.yaml`:

```yaml
openapi: "3.0.0"
info:
  title: <service-name>
  version: <version>
servers:
  - url: <connection.url from bindings, or http://localhost:8080>
paths:
  <path from bindings>:
    <method>:
      summary: <operation description>
      parameters: [...]   # path and query params from input fields
      requestBody:        # only for POST/PUT/PATCH
        content:
          application/json:
            schema: <input schema>
      responses:
        "200":
          content:
            application/json:
              schema: <output schema>
              example: <synthetic example — see below>
```

**Synthetic example generation rules:**
- `string` → `"<field-name>-example"` (e.g. `userId` → `"userId-example"`)
- `number` → `1`
- `boolean` → `true`
- `array` → single-element array of the items type
- `enum` → first value
- `object` → object with each field filled using same rules

Announce:
> "Generated `api-mock.yaml`. Start the mock server with:
> ```
> npx @stoplight/prism-cli mock api-mock.yaml
> ```
> Install once with: `npm install -g @stoplight/prism-cli`"

### Step 3b: gRPC mock (Go stub)

Generate a Go file `mock_server/main.go` that:
1. Implements the proto service interface with methods returning zero values
2. Starts a gRPC server on `:50051` (or the port from bindings)

Template:
```go
package main

import (
    "context"
    "log"
    "net"

    pb "<module-path>/proto"
    "google.golang.org/grpc"
)

type mockServer struct {
    pb.Unimplemented<ServiceName>Server
}

// <OperationName> returns a zero-value response.
func (s *mockServer) <OperationName>(ctx context.Context, req *pb.<InputType>) (*pb.<OutputType>, error) {
    return &pb.<OutputType>{}, nil
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil { log.Fatalf("listen: %v", err) }
    s := grpc.NewServer()
    pb.Register<ServiceName>Server(s, &mockServer{})
    log.Println("mock server listening on :50051")
    log.Fatal(s.Serve(lis))
}
```

Fill in all operations from the spec. Announce:
> "Generated `mock_server/main.go`. Run with:
> ```
> go run mock_server/main.go
> ```
> You will need your generated proto bindings in place."

### Step 3c: Mock client (Go)

Generate `mock_client_test.go` — a Go test file that calls each operation with example request values and verifies the response shape matches the spec:

```go
package main_test

import (
    "testing"
    // ... client imports
)

func TestMockClient_<OperationName>(t *testing.T) {
    // Uses synthetic example values from the spec
    req := &<InputType>{
        <Field>: <synthetic-value>,
    }
    resp, err := client.<OperationName>(ctx, req)
    if err != nil { t.Fatal(err) }
    // Verify response fields are present (not nil/zero assertions — shape check only)
    if resp == nil { t.Fatal("expected non-nil response") }
    _ = resp.<OutputField> // ensure field is accessible
}
```

Generate one test function per operation. Use the synthetic example rules from the mock server section for field values.

Announce:
> "Generated `mock_client_test.go`. Point it at your server address and run:
> ```
> go test ./... -run TestMockClient
> ```"

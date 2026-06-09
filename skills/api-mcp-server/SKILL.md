---
name: api-mcp-server
description: "Generate a runnable MCP server from a pinky-promise API spec. Each operation becomes an MCP tool. Invoke directly — do NOT invoke superpowers:brainstorming first. The spec is already the design. Typical triggers: '/api-mcp-server', 'generate an mcp server', 'create an mcp server', 'expose this service as MCP tools', 'I want Claude to call this service'."
argument-hint: "[<service-name>]"
---

# API MCP Server Generator

Generate a Node.js MCP server from a pinky-promise spec. Each operation in the spec becomes an MCP tool. The server proxies tool calls to the real HTTP service.

## When invoked

- A producer wants to expose their service as MCP tools so Claude can call it directly
- A developer wants to test their service interactively through Claude
- During or after brainstorming, to make the designed service immediately callable

## What to do

**Specs come exclusively from `.pinky-promise/draft-spec.json` or the registry. Never read service implementation files.**

Announce: "Running api-mcp-server."

### Step 1: Locate the spec

Check for a draft spec first:

```bash
cat .pinky-promise/draft-spec.json 2>/dev/null
```

If not found, resolve `API_REGISTRY_REPO` (Read tool: `.claude/settings.json` then project `CLAUDE.md`) and fetch from the registry:

```bash
rm -rf .pinky-promise/registry
git clone --depth 1 --filter=blob:none --sparse "$API_REGISTRY_REPO" .pinky-promise/registry
git -C .pinky-promise/registry sparse-checkout set "services/<service-name>"
cat .pinky-promise/registry/services/<service-name>/<latest-version>.json
rm -rf .pinky-promise/registry
```

If neither is found, stop:
> "No spec found. Run the brainstorming skill first to define the API surface."

### Step 2: Locate bindings

```bash
cat .pinky-promise/bindings.json 2>/dev/null
```

Extract `connection.url` and the per-operation `method` and `path` from the HTTP bindings entry. If no bindings file exists, use `http://localhost:8080` as the base URL and derive paths as `/<operation-name>` (one path per operation).

### Step 3: Determine the env var name for the service URL

Derive from the service name: uppercase, hyphens to underscores, append `_URL`.

Examples:
- `repo-stats` → `REPO_STATS_URL`
- `user-service` → `USER_SERVICE_URL`
- `payment-api` → `PAYMENT_API_URL`

### Step 4: Generate `mcp-server/mcp-server.js`

Write a Node.js ESM file. Use this exact structure — one `server.tool(...)` block per operation:

```javascript
#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "<service-name>",
  version: "<version from spec>",
});

// --- <operation-name> ---
server.tool(
  "<operation-name>",
  "<operation description from spec>",
  {
    // one entry per input field
    <field-name>: <zod-type>,
  },
  async (params) => {
    const baseUrl = process.env.<SERVICE_URL_ENV_VAR> ?? "<base-url from bindings or http://localhost:8080>";

    // Build the URL — replace path params, add query params for GET
    let path = "<path from bindings, e.g. /repos/{owner}/{repo}/stats>";
    <path-param-replacements>

    const url = new URL(path, baseUrl);
    <query-param-additions>

    const response = await fetch(url.toString(), {
      method: "<METHOD>",
      <body-if-post>
    });

    if (!response.ok) {
      throw new Error(`<service-name> returned ${response.status}: ${await response.text()}`);
    }

    const data = await response.json();
    return {
      content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
  }
);

// repeat server.tool(...) for each additional operation

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Field name-to-zod type mapping** (use for every input field):

| Spec type | Zod expression |
|---|---|
| `string` | `z.string()` |
| `integer` | `z.number().int()` |
| `number` | `z.number()` |
| `boolean` | `z.boolean()` |
| `array` of strings | `z.array(z.string())` |
| `array` of integers | `z.array(z.number().int())` |
| object or unknown | `z.record(z.unknown())` |

**Path parameter handling** (for each path template `{paramName}`):

```javascript
path = path.replace("{<paramName>}", encodeURIComponent(params.<paramName>));
```

**Query parameter handling** (GET only — input fields not consumed as path params):

```javascript
url.searchParams.set("<fieldName>", String(params.<fieldName>));
```

**Request body** (POST/PUT/PATCH — collect all non-path input fields):

```javascript
headers: { "Content-Type": "application/json" },
body: JSON.stringify({ <fieldName>: params.<fieldName>, ... }),
```

### Step 5: Generate `mcp-server/package.json`

```json
{
  "name": "<service-name>-mcp-server",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node mcp-server.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.0.0"
  }
}
```

### Step 6: Output setup instructions

Print exactly this block (substituting service name and env var):

```
Generated mcp-server/mcp-server.js and mcp-server/package.json.

Install dependencies:
  cd mcp-server && npm install

Add to .claude/settings.json to use in Claude Code:

  "mcpServers": {
    "<service-name>": {
      "command": "node",
      "args": ["./mcp-server/mcp-server.js"],
      "env": {
        "<SERVICE_URL_ENV_VAR>": "http://localhost:8080"
      }
    }
  }

Then restart your Claude Code session. Claude will have a '<operation-name>' tool for each operation in the spec.
```

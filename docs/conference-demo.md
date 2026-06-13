# Conference Demo Script — pinky-promise (20 min)

## Narrative arc

You build a Go service (`repo-stats`) live. Claude captures the API contract during the design conversation, publishes it to a shared registry at branch completion, then generates an MCP server from the spec — making Claude itself the first consumer. To close, you propose a breaking change and the guardian catches it before a line of code is written.

One project. One session restart. Every pinky-promise skill fires from natural conversation prompts.

---

## Prerequisites — do this before the talk

### 1. Set up the API registry (once)

```bash
mkdir api-registry && cd api-registry
git init && mkdir -p services && touch services/.gitkeep
git add . && git commit -m "chore: init"
git remote add origin git@github.com:<yourorg>/api-registry.git
git push -u origin main
```

### 2. Create the project directory

```bash
mkdir repo-stats && cd repo-stats && git init
```

### 3. Install superpowers + pinky-promise

```bash
claude plugin marketplace add https://github.com/superluminar-io/pinky-promise
claude plugin install pinky-promise@superluminar-io --scope project
```

### 4. Configure the registry

Add to `repo-stats/.claude/settings.json`:

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:<yourorg>/api-registry.git"
  }
}
```

### 5. Pre-stage the MCP server dependencies

You'll generate `mcp-server/package.json` live, but `npm install` is slow on stage. Run this once now so the install is instant during the demo:

```bash
mkdir -p repo-stats/mcp-server
cd repo-stats/mcp-server
npm install @modelcontextprotocol/sdk zod
```

### 6. Pre-build the Go service

Claude will generate the Go code during the demo, but `go run` compilation is slow on stage. After a dry run, copy the working binary to `repo-stats/repo-stats-bin` so you can fall back to it:

```bash
cd repo-stats
go build -o repo-stats-bin .
```

### 7. Pre-flight check (30 min before the talk)

- [ ] Claude Code session open in `repo-stats` (no `.pinky-promise/` directory yet)
- [ ] Second terminal open in `repo-stats/` for running the service
- [ ] Registry reachable: `git ls-remote $API_REGISTRY_REPO`
- [ ] `node --version` works in repo-stats/mcp-server (Node 18+)
- [ ] GitHub is reachable: `curl https://api.github.com/repos/superluminar-io/pinky-promise`
- [ ] Font size readable from the back of the room

---

## The Demo

### [0:00] Opening — 1 min

**Say:**
> "APIs break silently. Service A renames a field, Service B's tests still pass because they mock everything, and you find out in production at 2am.
>
> pinky-promise makes API contracts explicit, versioned, and enforced automatically inside Claude Code — during design, implementation, and branch completion.
>
> I'm going to build a service from scratch, publish its contract, and then use Claude as the first consumer — without writing a single client line."

---

### [1:00] Act 1 — Design the service — 5 min

**Window:** Claude Code in `repo-stats/`

**Type this prompt:**

```
I want to build a repo-stats service in Go. It should expose a simple API
that other services can call to get basic stats for a GitHub repository —
star count, fork count, open issue count. Internally it fetches that data
from the GitHub REST API. No persistence needed, just a thin facade over GitHub.
```

**What Claude does:**
Invokes `superpowers:brainstorming` AND `api-spec-brainstorming` simultaneously. Before asking anything else, it surfaces:

> "The design depends on `github-rest-api` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."

**Say while that appears:**
> "Notice Claude caught that this service depends on the GitHub REST API — and there's no registry entry for it. In a real project we'd import GitHub's OpenAPI spec here. For this demo, we'll focus on repo-stats' own contract."

**Type:** `Let's skip the GitHub import for now and focus on repo-stats' own API.`

Claude asks about the API surface. Answer these questions:

| Claude asks | You answer |
|---|---|
| "What operations does repo-stats need to expose?" | `One operation: getRepoStats. Input is owner and repo, both strings. Output is a RepoStats object with starCount, forkCount, and openIssueCount as integers.` |
| "When should a caller use this operation?" | `When they need to display or process repository metrics. It's the only operation.` |
| "Does it emit any events?" | `No events.` |
| "Any subscriptions or streams?" | `No.` |
| "Which protocol?" | Select **HTTP JSON REST** |
| "What's the endpoint?" | `GET /repos/{owner}/{repo}/stats` |
| "Does this require auth from consumers?" | `No, public repos only, no auth needed.` |

**What Claude does:**
Writes `.pinky-promise/draft-spec.json` with the operation, the `RepoStats` type, and the HTTP binding.

**Say:**
> "That draft spec lives in the repo alongside the code. It's the contract — not a comment, not a wiki page. Everything from here on reads this file."

---

### [6:00] Act 2 — Implement — 2 min

**Type:**

```
Let's implement this. Generate the Go HTTP handler and the GitHub API client.
No framework, just stdlib.
```

**What Claude does:** Generates `main.go`, `handler.go`, `github_client.go`. No pinky-promise involvement here.

**Say while Claude codes:**
> "Implementation is just implementation. pinky-promise doesn't get in the way."

---

### [8:00] Act 3 — Publish the contract — 2 min

**Type:**

```
This looks good. Let's finish the branch.
```

**What Claude does:**
Invokes `superpowers:finishing-a-development-branch`, detects `.pinky-promise/draft-spec.json`, invokes `api-spec-publish`.

Claude confirms the version:

> Publish **repo-stats** as **1.0.0** (first publish)?
> - Publish repo-stats as 1.0.0
> - Cancel

**Select:** Publish repo-stats as 1.0.0

Claude commits the spec to the registry and deletes the draft. After publishing it offers follow-up tooling — **select Nothing, I'm done**. We'll generate the MCP server separately for more impact.

---

### [10:00] Act 4 — Generate the MCP server — 2 min

**Type:**

```
/api-mcp-server
```

**What Claude does:**
Reads the just-published spec from the registry, generates `mcp-server/mcp-server.js` with one MCP tool per operation, generates `mcp-server/package.json`, and prints the settings.json snippet:

```json
"mcpServers": {
  "repo-stats": {
    "command": "node",
    "args": ["./mcp-server/mcp-server.js"],
    "env": {
      "REPO_STATS_URL": "http://localhost:8080"
    }
  }
}
```

**Say:**
> "The spec we just defined now describes an MCP tool. The `description` field we wrote during brainstorming — 'use when you need to display or process repository metrics' — becomes the tool description Claude reads to decide when to call it."

**While Claude generates:** Open `.claude/settings.json` and paste in the `mcpServers` block shown by Claude.

---

### [12:00] Act 5 — Claude as client — 3 min

**In the second terminal**, start the repo-stats service:

```bash
go run .
# or use the pre-built binary if compilation is slow:
./repo-stats-bin
```

**Back in the Claude Code window**, install MCP server dependencies (instant — pre-staged):

```bash
cd mcp-server && npm install
```

**Restart the Claude Code session** (close and reopen, or `/exit` then `claude`). The MCP server is now configured and Claude Code starts it automatically.

**Type:**

```
How many stars does superluminar-io/pinky-promise have?
```

**What Claude does:** Calls the `getRepoStats` MCP tool with `owner="superluminar-io"`, `repo="pinky-promise"`. The MCP server calls `GET localhost:8080/repos/superluminar-io/pinky-promise/stats`. Claude returns the live count.

**Say:**
> "Claude just called the service we designed ten minutes ago. The same spec that captured the contract now tells Claude how to invoke it. No glue code, no manual tool definition — it came from the contract."

---

### [15:00] Act 6 — The breaking change — 3 min

**Type:**

```
The field names starCount, forkCount, openIssueCount feel verbose.
Let's rename them to just stars, forks, issues in the RepoStats response.
```

**What Claude does:**
Before planning anything, CLAUDE.md detects a proposed change to the published interface and invokes `api-change-guardian`.

Guardian output:

> Running api-change-guardian to check for API contract changes.
>
> **Proposed changes to repo-stats @ 1.0.0:**
>
> | Field | Change | Classification |
> |---|---|---|
> | `RepoStats.starCount` | renamed to `stars` | **MAJOR** |
> | `RepoStats.forkCount` | renamed to `forks` | **MAJOR** |
> | `RepoStats.openIssueCount` | renamed to `issues` | **MAJOR** |
>
> These are breaking changes. Any consumer pinned to 1.0.0 will break without a coordinated migration.
>
> How do you want to proceed?
> - Proceed — bump to 2.0.0 and record the decision
> - Defer — continue planning, resolve before publish
> - Reject — keep the existing names

**Say while this appears:**
> "This is the moment pinky-promise is built for. We haven't written a line of code yet — and we already know this is a breaking change, we know what it breaks, and we're forced to make a conscious decision."

**Select:** Proceed — bump to 2.0.0 and record the decision

**Say:**
> "When we finish this branch, api-spec-publish will push 2.0.0 and preserve the 1.x binding alongside it — old consumers keep working while new ones use the renamed fields. The decision is in the spec, not in someone's head."

---

### [18:00] Closing — 2 min

**Say:**
> "Five skills. One project. Zero manual steps.
>
> Brainstorming captured the API surface. Branch completion published it. An MCP server came out of the spec automatically. And a rename that would have broken every consumer was caught before a single line of code was written.
>
> The contract is in git. It travels with the code. Every stage of the workflow reads it.
>
> pinky-promise is open source. Install it in 30 seconds."

Show on screen:

```bash
claude plugin marketplace add https://github.com/superluminar-io/pinky-promise
claude plugin install pinky-promise@superluminar-io --scope project
```

---

## Recovery notes

| What went wrong | What to do |
|---|---|
| `api-spec-brainstorming` didn't fire | Type `/api-spec-brainstorming` to invoke manually |
| `api-change-guardian` didn't fire | Type `Run api-change-guardian on this change` |
| Registry clone fails | Say "this connects to a private SSH registry — you'd see this on a real network" and proceed with the draft spec visible on screen |
| Claude asks too many clarifying questions | Answer in bulk: type all answers in one message |
| `go run` is slow | Use the pre-built binary: `./repo-stats-bin` |
| `npm install` is slow | It was pre-staged — if it's still slow, skip to the next act and say "in practice this is a one-time setup" |
| MCP tool call fails | Say "the service isn't responding locally — here's what the tool call looks like" and show the generated mcp-server.js |
| Claude misclassifies the rename | Say "let's ask the guardian directly" and type `/api-change-guardian` |

## Skills demonstrated

| Skill | Act |
|---|---|
| `api-spec-brainstorming` | Act 1 — API surface captured during design |
| `api-spec-publish` | Act 3 — contract versioned and pushed to registry |
| `api-mcp-server` | Act 4 — MCP server generated from published spec |
| `api-change-guardian` | Act 6 — breaking rename caught before implementation |

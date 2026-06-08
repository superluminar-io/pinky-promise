# Conference Demo Script — pinky-promise (20 min)

## Narrative arc

You build a Go service (`repo-stats`) live. Claude automatically captures its public API contract during the design conversation, publishes it to a shared registry when the branch is done, then validates a consumer service against that contract — and catches a breaking change before a single line of implementation code is written.

Every pinky-promise skill fires naturally from conversational prompts. You don't invoke anything manually.

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

### 2. Create the two project directories

```bash
mkdir repo-stats && cd repo-stats && git init
mkdir dashboard-service && cd dashboard-service && git init
```

### 3. Install superpowers + pinky-promise in both

From each project directory:

```bash
claude plugin marketplace add https://github.com/superluminar-io/pinky-promise
claude plugin install pinky-promise@superluminar-io --scope project
```

### 4. Configure the registry in both

Add to `.claude/settings.json` in **both** projects:

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:<yourorg>/api-registry.git"
  }
}
```

### 5. Pre-flight check (30 min before the talk)

- [ ] Both Claude Code sessions open in separate terminal windows
- [ ] `repo-stats` window is active and empty (no `.pinky-promise/` directory)
- [ ] `dashboard-service` window is ready but not yet used
- [ ] Registry is reachable: `git ls-remote $API_REGISTRY_REPO`
- [ ] Font size readable from the back of the room

---

## The Demo

### [0:00] Opening — 1 min

**Say:**
> "APIs break silently. Service A renames a field, Service B's tests still pass because they mock everything, and you find out in production at 2am.
>
> pinky-promise makes API contracts explicit, versioned, and enforced automatically inside Claude Code — during design, planning, code review, and branch completion.
>
> I'm going to build a service from scratch and show you every stage."

---

### [1:00] Act 1 — Design the service — 5 min

**Window:** `repo-stats`

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
> "Notice Claude caught that repo-stats calls the GitHub REST API — and there's no registry entry for it. In a real project we'd import GitHub's OpenAPI spec here. For this demo we'll proceed without it — what we care about is repo-stats' own contract."

**Type:** `Let's skip the GitHub import for now and focus on repo-stats' own API.`

Claude then asks about the API surface. Answer these questions:

| Claude asks | You answer |
|---|---|
| "What operations does repo-stats need to expose?" | `One operation: getRepoStats. Input is owner and repo, both strings. Output is a RepoStats object with starCount, forkCount, and openIssueCount as integers.` |
| "When should a caller use this operation?" | `When they need to display or process repository metrics. It's the only operation, no alternative.` |
| "Does it emit any events?" | `No events.` |
| "Any subscriptions or streams?" | `No.` |
| "Which protocol?" | Select **HTTP JSON REST** |
| "What's the endpoint?" | `GET /repos/{owner}/{repo}/stats` |
| "Does this require auth from consumers?" | `No, public repos only, no auth needed.` |

**What Claude does:**
Writes `.pinky-promise/draft-spec.json`. The spec captures the operation, the `RepoStats` type, and the bindings. 

**Say:**
> "That draft spec lives in the repo alongside the code. It's the contract. Not a comment, not a wiki page — a versioned JSON file that every other tool in this workflow reads."

---

### [6:00] Act 2 — Implement — 2 min

**Type:**

```
Let's implement this. Generate the Go HTTP handler and the GitHub API client.
No framework needed, just stdlib.
```

**What Claude does:** Generates `main.go`, `handler.go`, `github_client.go`. No pinky-promise involvement here — this is plain implementation.

**Say while Claude codes:**
> "Implementation is just implementation. pinky-promise doesn't get in the way — it only fires at the moments that matter for contracts."

---

### [8:00] Act 3 — Publish the contract — 2 min

**Type:**

```
This looks good. Let's finish the branch.
```

**What Claude does:**
Invokes `superpowers:finishing-a-development-branch`, which detects `.pinky-promise/draft-spec.json` and invokes `api-spec-publish`.

Claude presents a confirmation:

> Publish **repo-stats** as **1.0.0** (first publish)?
> - Publish repo-stats as 1.0.0
> - Cancel

**Select:** Publish repo-stats as 1.0.0

Claude commits the spec to the registry and cleans up the draft.

After publishing, Claude offers follow-up tooling:
> - Generate mock server
> - Generate Pact contract tests
> - Nothing, I'm done

**Select:** Generate mock server

**What Claude does:** Invokes `api-mock-server` and generates a Prism-compatible mock HTTP server config from the spec.

**Say:**
> "The mock server means consumers can build against repo-stats before a single line of implementation exists. Contract-first development, automatically."

---

### [10:00] Act 4 — Build a consumer — 5 min

**Switch window to:** `dashboard-service`

**Type:**

```
I'm building a dashboard service. It needs to show repository stats on a
web page for a list of projects. I want to call the repo-stats service to
get star count, fork count, and open issue count for each repo.
```

**What Claude does:**
Invokes `superpowers:brainstorming`. CLAUDE.md detects this mentions calling `repo-stats`, fetches the spec from the registry, and invokes `api-contract-check`.

Since `api-dependencies.json` doesn't exist yet, Claude asks which services the dashboard consumes and which version to pin. 

**Answer:** `repo-stats`, pin to `1.0.0`

Claude creates `api-dependencies.json` and validates the plan against the published spec.

**Say:**
> "Claude just fetched repo-stats' contract from the registry — without touching the repo-stats codebase. The registry is the only source of truth."

**Type:**

```
Let's write the implementation. HTTP client that calls repo-stats, then
renders the results as an HTML table.
```

After Claude implements:

**Type:**

```
/requesting-code-review
```

**What Claude does:**
Runs `api-contract-check` as part of the review. It validates that every call the dashboard makes to repo-stats matches the pinned 1.0.0 contract — correct operation name, correct input fields, correct response fields.

**Say:**
> "Contract check runs automatically on every code review for consumer code. If the implementation ever drifts from the spec — wrong field name, wrong type — it gets caught here, not in production."

---

### [15:00] Act 5 — The breaking change — 4 min

**Switch window back to:** `repo-stats`

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
> These are **breaking changes**. Consumers pinned to 1.0.0 (e.g. `dashboard-service`) will break if they upgrade without updating their code.
>
> How do you want to proceed?
> - Proceed — bump to 2.0.0 and record the decision
> - Defer — continue planning, resolve before publish
> - Reject — keep the existing names

**Say while this appears:**
> "This is the moment pinky-promise is built for. The guardian caught a breaking change before a single line of code was written. The dashboard team pinned to 1.0.0 — they'd break silently if this slipped through."

**Select:** Proceed — bump to 2.0.0 and record the decision

**What Claude does:** Records the decision, marks the draft spec as 2.0.0, notes that consumers on 1.0.0 will need to migrate.

**Say:**
> "The decision is recorded in the spec. When we finish this branch, api-spec-publish will bump to 2.0.0 and preserve the 1.x binding alongside the 2.x binding — old consumers keep working while new ones use the renamed fields."

---

### [19:00] Closing — 1 min

**Say:**
> "Six integration points. Zero manual steps. The API contract lives in git, validated at every stage of the workflow.
>
> Brainstorming captures the surface. Planning validates consumers. Code review catches drift. Branch completion publishes. The guardian blocks breaking changes before they're planned.
>
> pinky-promise is open source at github.com/superluminar-io/pinky-promise. Install it in 30 seconds with the commands on screen. Thank you."

Show on screen:
```bash
claude plugin marketplace add https://github.com/superluminar-io/pinky-promise
claude plugin install pinky-promise@superluminar-io --scope project
```

---

## Recovery notes

| What went wrong | What to do |
|---|---|
| api-spec-brainstorming didn't fire automatically | Type `/api-spec-brainstorming` to invoke manually |
| api-change-guardian didn't fire | Type `Run api-change-guardian on this change` |
| Registry clone fails | Say "the registry is a private SSH repo — you'd see this work on a real network" and proceed with the draft spec visible on screen |
| Claude asks too many clarifying questions | Answer in bulk: type all the answers in one message |
| Implementation takes too long | Skip to the next step — the code isn't the point |
| Claude misclassifies the breaking change | Say "let's ask the guardian directly" and type `/api-change-guardian` |

## What each skill demonstrated

| Skill | Where in demo |
|---|---|
| `api-spec-brainstorming` | Act 1 — API surface captured during design |
| `api-spec-publish` | Act 3 — contract versioned and pushed to registry |
| `api-mock-server` | Act 3 — mock server generated from published spec |
| `api-contract-check` | Act 4 — consumer plan and code validated against spec |
| `api-change-guardian` | Act 5 — breaking rename caught before implementation |

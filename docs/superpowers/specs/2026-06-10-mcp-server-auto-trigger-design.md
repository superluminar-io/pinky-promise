# MCP Server Auto-Trigger Fix

## Problem

When a user says "generate an mcp server for this service", Claude invokes
`superpowers:brainstorming` + `pinky-promise:api-spec-brainstorming` instead of
`pinky-promise:api-mcp-server`. Root cause: the service-design hook in CLAUDE.md
("building... a service → brainstorm") fires before the MCP override hook, and
the `using-superpowers` "process skills first" rule reinforces it.

## Changes

### 1. New test: `tests/claude-code/test-mcp-server-triggers.sh`

Mirrors `test-brainstorming-triggers.sh`. Three cases:
- `"generate an mcp server"`
- `"generate an mcp server for this service"`
- `"generate an mcp server from the specs"`

Each checks stream-json for:
- `api-mcp-server` Skill invocation present
- `brainstorming` Skill invocation absent

Added to `tests/claude-code/run-all.sh`.

### 2. `skills/api-mcp-server/SKILL.md` — frontmatter description

Rewrite to lead with `OVERRIDES superpowers:brainstorming and api-spec-brainstorming.
Invoke IMMEDIATELY — before brainstorming, before any other skill —` and add all
user-facing trigger phrases including "generate an mcp server from the specs" and
"generate an mcp server for this service".

### 3. `CLAUDE.md` — two edits

**Edit A:** Move the MCP hook section above the service-design hook so it is read first.

**Edit B:** Add an explicit exception inside the service-design hook:
> "Exception: if the message contains 'mcp server', 'mcp tools', 'expose as tools',
> or 'claude to call this service', skip this rule — invoke `pinky-promise:api-mcp-server` instead."

## Out of scope

- Version bump (happens at merge to main)
- Changes to the MCP server generation logic itself

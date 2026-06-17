# Contributing to pinky-promise

Thank you for your interest in contributing. This guide covers everything you need to get started.

## Prerequisites

- Claude Code with the [superpowers](https://github.com/obra/superpowers) plugin installed
- A git repository to use as an API registry (see [docs/registry-setup.md](docs/registry-setup.md))
- Node.js 18+ (for integration tests and the MCP server skill)
- Go 1.21+ (for the test fixture services)

## Development setup

```bash
git clone git@github.com:superluminar-io/pinky-promise.git
cd pinky-promise
./install-local.sh /path/to/a/test-project
```

`install-local.sh` registers the plugin from your local checkout into a test project so you can try changes immediately without publishing.

To pick up edits after changing a skill:

```bash
./install-local.sh /path/to/a/test-project --update
```

## Running tests

```bash
# Fast: plugin load check + qualitative skill-content questions (~3–5 min)
make test

# Integration: full headless Claude sessions against a real registry (~10–15 min)
make integration-test

# Everything
make slow-test
```

Integration tests require a reachable registry. Set `API_REGISTRY_REPO` in your environment or `.claude/settings.json` before running them.

## Branching and pull requests

- All changes go on a feature branch — never commit directly to `main`.
- Branch naming: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`.
- Open a PR against `main`. Draft PRs are fine for work in progress.
- Squash merges only — keep `main` history linear.
- Branches are deleted automatically after merge.

## Versioning

Every PR that lands on `main` must include a version bump in `plugin.json`, `marketplace.json`, and `package.json`. All three must carry the same version string. Do not bump versions on feature branches — apply the bump as part of the merge.

Use this table to determine the correct bump:

| Change | Bump |
|---|---|
| Bug fix, skill clarification, improved wording | patch |
| New skill, new CLAUDE.md hook, new optional IDL field, new auth type | minor |
| Rename or remove a field in contract files or `bindings.json` | **major** |
| Change the semantics of an existing field | **major** |
| Change the registry layout | **major** |
| Remove or rename a skill | **major** |

If you are unsure whether a change is breaking, assume it is and flag it in the PR.

## Contributor License Agreement

By submitting a pull request you agree that your contribution is licensed under the Apache License 2.0, including the patent grant in Section 3. There is no separate CLA to sign.

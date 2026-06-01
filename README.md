# pinky-swear

A Claude Code plugin for managing API contracts between producer and consumer services. It integrates with the [superpowers](https://claude.com/plugins/superpowers) development workflow to keep your service interfaces consistent across teams.

## Requirements

- Claude Code with the superpowers plugin installed (`/plugin install superpowers@claude-plugins-official`)
- SSH access to a git repository for the API registry (see [Registry Setup](#registry-setup))

## Installation

```
/plugin install superluminar-io/pinky-swear
```

## Registry Setup

pinky-swear uses a separate git repository as an API registry. Create one before configuring the plugin:

```bash
mkdir api-registry && cd api-registry
git init
mkdir -p services && touch services/.gitkeep
git add services/ && git commit -m "chore: init registry"
git remote add origin git@github.com:yourorg/api-registry.git
git push -u origin main
```

See `docs/registry-setup.md` for the full registry layout and commit format.

## Configuration

Point pinky-swear at your registry by adding the following to your project's `CLAUDE.md`:

```
API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
```

Or in `.claude/settings.json`:

```json
{
  "env": {
    "API_REGISTRY_REPO": "git@github.com:yourorg/api-registry.git"
  }
}
```

If `API_REGISTRY_REPO` is not set, all skills warn and skip silently — they never block your work.

## How It Works

Once installed, pinky-swear hooks into the superpowers workflow automatically:

- **Brainstorming**: prompts you to define your service's public interface if no spec exists yet, or flags breaking changes against a published spec
- **Planning**: checks that calls to other services match their published contracts before the plan is finalized
- **Code review**: verifies consumer code against published specs and flags interface changes in producer code
- **Branch completion**: publishes a new spec version when you finish a branch that changes your public interface

## Usage

See `docs/idl-reference.md` for the API spec format and `docs/registry-setup.md` for registry administration.

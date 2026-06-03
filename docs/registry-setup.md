# Registry Setup

The API registry is a separate git repository. All writes come from the `api-spec-publish` skill — no human commits.

## Creating the registry

```bash
mkdir api-registry
cd api-registry
git init
mkdir -p services
touch services/.gitkeep
git add services/
git commit -m "chore: init registry"
git remote add origin git@github.com:yourorg/api-registry.git
git push -u origin main
```

## Configuring the registry URL

In your project's CLAUDE.md:

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

## Registry layout

```
api-registry/
  services/
    user-service/
      1.0.0.json      ← abstract contract (versioned, immutable)
      1.1.0.json
      2.0.0.json
      bindings.json   ← protocol mappings + auth (not versioned, overwritten on publish)
    payment-service/
      1.0.0.json
      bindings.json
```

Each service has versioned contract files (named by semver) and a single `bindings.json`. Contract files are immutable once published. `bindings.json` is always overwritten on publish and tracks the current deployment state across all active contract versions.

## Commit format

Every publish creates a commit in the format:

```
<service-name>: <version> (<bump>) — <summary>
```

Examples:
```
user-service: 1.1.0 (minor) — added listUsers operation
user-service: 2.0.0 (major) — removed deprecated getUser, redesigned auth model
payment-service: 1.0.1 (patch) — updated connection URL
```

## Authentication

Skills use standard git over SSH. The machine running Claude Code must have SSH access configured for the registry repo.

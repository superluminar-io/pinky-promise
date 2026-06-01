# Registry Setup

The API registry is a separate git repository. All writes come from the `api-spec-publish` skill — no human commits.

## Creating the registry

```bash
mkdir api-registry
cd api-registry
git init
mkdir -p services
git add services
git commit --allow-empty -m "chore: init registry"
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
      1.0.0.json
      1.1.0.json
      2.0.0.json
    payment-service/
      1.0.0.json
```

One JSON file per service version, named by semver. The highest semver in a directory is the latest version. Published versions are immutable.

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

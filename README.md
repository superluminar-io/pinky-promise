# pinky-swear

A Claude Code plugin for managing API contracts between producer and consumer services.

## Requirements

- Claude Code with superpowers plugin installed

## Setup

1. Create a dedicated git repository for your API registry (see `docs/registry-setup.md`)
2. In your project's CLAUDE.md, add:
   ```
   API_REGISTRY_REPO=git@github.com:yourorg/api-registry.git
   ```
3. Install this plugin

## Usage

See `docs/idl-reference.md` for the spec format and `docs/registry-setup.md` for registry setup.

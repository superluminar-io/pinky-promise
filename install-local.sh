#!/usr/bin/env bash
set -euo pipefail

PLUGIN_SRC="$(cd "$(dirname "$0")" && pwd)"
MARKETPLACE_NAME="superluminar-io"

usage() {
  echo "Usage: $0 <project-path> [--update]" >&2
  echo "  $0 ~/src/github.com/superluminar-io/pinky-promise-test-user          # first install" >&2
  echo "  $0 ~/src/github.com/superluminar-io/pinky-promise-test-user --update  # sync changes" >&2
  exit 1
}

PROJECT_PATH="${1:-}"
UPDATE=false
[[ "${2:-}" == "--update" ]] && UPDATE=true

[[ -z "$PROJECT_PATH" ]] && usage

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: directory does not exist: $PROJECT_PATH" >&2
  exit 1
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI is required but not found." >&2
  exit 1
fi

cd "$PROJECT_PATH"

if [[ "$UPDATE" == "true" ]]; then
  echo "Syncing pinky-promise changes..."
  # Clean up old name from before the rename
  claude plugin uninstall "pinky-swear@$MARKETPLACE_NAME" --scope project 2>/dev/null || true
  claude plugin uninstall "pinky-promise@$MARKETPLACE_NAME" --scope project 2>/dev/null || true
  # Re-register and refresh marketplace from local source
  claude plugin marketplace add "$PLUGIN_SRC" --scope project 2>/dev/null || true
  claude plugin marketplace update "$MARKETPLACE_NAME" 2>/dev/null || true
  # Wipe the cache so the reinstall copies fresh files rather than reusing the old 1.0.0 directory
  rm -rf "$HOME/.claude/plugins/cache/$MARKETPLACE_NAME"
  claude plugin install "pinky-promise@$MARKETPLACE_NAME" --scope project
  echo "Done. Plugin updated in $PROJECT_PATH."
else
  echo "Registering pinky-promise marketplace..."
  claude plugin marketplace add "$PLUGIN_SRC" --scope project

  echo "Installing pinky-promise..."
  claude plugin install "pinky-promise@$MARKETPLACE_NAME" --scope project

  echo "Done. Plugin installed for $PROJECT_PATH only."
  echo ""
  echo "To pick up changes after editing the plugin source:"
  echo "  $0 $PROJECT_PATH --update"
fi

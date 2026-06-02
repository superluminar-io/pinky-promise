#!/usr/bin/env bash
set -euo pipefail

PLUGIN_SRC="$(cd "$(dirname "$0")" && pwd)"
MARKETPLACE_NAME="pinky-swear-local"

PROJECT_PATH="${1:-}"
if [[ -z "$PROJECT_PATH" ]]; then
  echo "Usage: $0 <project-path>" >&2
  echo "  Example: $0 ~/src/github.com/superluminar-io/pinky-swear-test-user" >&2
  exit 1
fi

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

echo "Registering pinky-swear marketplace..."
claude plugin marketplace add "$PLUGIN_SRC" --scope project

echo "Installing pinky-swear..."
claude plugin install "pinky-swear@$MARKETPLACE_NAME" --scope project

echo "Done. Plugin installed for $PROJECT_PATH only."

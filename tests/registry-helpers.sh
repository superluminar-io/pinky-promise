#!/usr/bin/env bash
# Shared helpers for integration tests that need a local registry.
# Source this file; do not run it directly.

# Create a bare git repo with an empty initial commit on main.
# Prints the repo path.
# Usage: REGISTRY=$(create_bare_registry)
create_bare_registry() {
  local bare
  bare=$(mktemp -d)
  git init --bare "$bare" -q

  # Seed an initial commit so main exists and the repo is pushable
  local seed
  seed=$(mktemp -d)
  git -C "$seed" init -q
  git -C "$seed" remote add origin "$bare"
  git -C "$seed" commit --allow-empty -m "init" -q
  git -C "$seed" push origin HEAD:main -q
  rm -rf "$seed"

  echo "$bare"
}

# Push a contract file into a bare registry under services/<name>/<version>.json.
# Optionally push a bindings file as services/<name>/bindings.json.
# Usage: seed_registry_spec <bare-repo-path> <contract-file> [bindings-file]
seed_registry_spec() {
  local bare="$1"
  local spec_file="$2"
  local bindings_file="${3:-}"
  local name version

  name=$(python3 -c "import sys,json; print(json.load(open('$spec_file'))['name'])")
  version=$(python3 -c "import sys,json; print(json.load(open('$spec_file'))['version'])")

  local seed
  seed=$(mktemp -d)
  git -C "$seed" init -q
  git -C "$seed" remote add origin "$bare"
  git -C "$seed" fetch origin main -q
  git -C "$seed" checkout -b main FETCH_HEAD -q

  mkdir -p "$seed/services/$name"
  cp "$spec_file" "$seed/services/$name/$version.json"
  git -C "$seed" add "services/$name/$version.json"

  if [[ -n "$bindings_file" ]]; then
    cp "$bindings_file" "$seed/services/$name/bindings.json"
    git -C "$seed" add "services/$name/bindings.json"
  fi

  git -C "$seed" commit -m "$name: $version" -q
  git -C "$seed" push origin main -q
  rm -rf "$seed"
}

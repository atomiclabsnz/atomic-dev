#!/usr/bin/env bash
# One-command setup for a fresh machine:
#   curl -fsSL https://raw.githubusercontent.com/CHANGE-ME/atomic-dev/main/bootstrap.sh | bash -s -- [install.sh options]
# Clones (or updates) this repo into ~/.atomic-dev, then runs install.sh with the same options.
# Env: ATOMIC_REPO_URL, ATOMIC_REF (branch/tag, default main), ATOMIC_HOME (checkout dir)
set -euo pipefail

# Everything is in main() so a partially downloaded script never runs
main() {
  local repo_url="${ATOMIC_REPO_URL:-https://github.com/CHANGE-ME/atomic-dev.git}"
  local ref="${ATOMIC_REF:-main}"
  local dest="${ATOMIC_HOME:-$HOME/.atomic-dev}"

  if ! command -v git >/dev/null 2>&1; then
    echo "==> Installing git"
    local sudo=""; [ "$(id -u)" -eq 0 ] || sudo="sudo"
    if command -v apt-get >/dev/null; then
      $sudo apt-get update -qq && $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ca-certificates curl
    elif command -v pacman >/dev/null; then
      $sudo pacman -Sy --needed --noconfirm git
    else
      echo "Please install git (macOS: xcode-select --install) and re-run." >&2; exit 1
    fi
  fi

  if [ -d "$dest/.git" ]; then
    echo "==> Updating $dest"
    git -C "$dest" fetch --quiet origin "$ref"
    git -C "$dest" checkout --quiet "$ref"
    git -C "$dest" merge --quiet --ff-only FETCH_HEAD
  else
    echo "==> Cloning $repo_url into $dest"
    git clone --quiet --branch "$ref" "$repo_url" "$dest"
  fi

  # stdin is this script when piped from curl; don't let installers read it
  exec bash "$dest/install.sh" "$@" </dev/null
}

main "$@"

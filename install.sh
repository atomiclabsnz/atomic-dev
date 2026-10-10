#!/usr/bin/env bash
# Set up the atomic-dev environment on this machine. Safe to re-run: it's also the update path.
# Usage: install.sh [--user NAME] [--no-claude] [--no-rust] [--no-docker] [--auto-attach DIR]
# Env:   GIT_NAME, GIT_EMAIL, ATOMIC_REPOS="org/repo ...", CLAUDE_CODE_OAUTH_TOKEN
set -euo pipefail

ATOMIC_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/common.sh
. "$ATOMIC_HOME/lib/common.sh"

usage() { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

NEW_USER="" WITH_CLAUDE=1 WITH_RUST=1 WITH_DOCKER=1 AUTO_ATTACH="" SKIP_BASE=0 IN_CONTAINER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --user) NEW_USER=${2:?--user needs a name}; shift ;;
    --no-claude) WITH_CLAUDE=0 ;;
    --no-rust) WITH_RUST=0 ;;
    --no-docker) WITH_DOCKER=0 ;;
    # internal (bin/ide-devcontainer): inside a project's dev container, which brings its own
    # toolchain, so keep the base packages minimal and skip Rust and Docker
    --container) IN_CONTAINER=1 WITH_RUST=0 WITH_DOCKER=0 ;;
    --auto-attach) AUTO_ATTACH=${2:?--auto-attach needs a directory}; shift ;;
    --skip-base) SKIP_BASE=1 ;;   # internal: base packages already installed by root
    -h|--help) usage ;;
    *) warn "Unknown option: $1"; usage 1 ;;
  esac
  shift
done

detect_os
say "atomic-dev on $OS ($(uname -m)) from $ATOMIC_HOME"

for step in "$ATOMIC_HOME"/steps/*.sh; do
  # shellcheck source=/dev/null
  . "$step"
done

cat <<'MSG'

Done. Open a new shell (or `exec $SHELL -l`), then run `ide` in a project (or in ~ to pick one).

  Ctrl-q then h / l   file tree / editor        Ctrl-q then /   cheat sheet
  Ctrl-q then c       Claude tab                Ctrl-q then 1-4 code / claude / git / shell
  Ctrl-q then g       git tab
  Ctrl-q then d       detach (keeps running)    Ctrl-q then q   quit the session
  Ctrl-q keys also work as Alt+key in one go (claude is Alt 2, quit is Alt Shift q).

Alt keys need your local terminal to send Option as Alt (iTerm2: Left Option = Esc+,
Terminal.app: "Use Option as Meta key", Ghostty: macos-option-as-alt = left).
Claude Code: run `claude` and follow the login link, or export CLAUDE_CODE_OAUTH_TOKEN / ANTHROPIC_API_KEY.
MSG

#!/usr/bin/env bash
# Set up the atomic-dev environment on this machine. Safe to re-run: it's also the update path.
# Usage: install.sh [--user NAME] [--no-claude] [--no-rust] [--auto-attach DIR]
# Env:   GIT_NAME, GIT_EMAIL, ATOMIC_REPOS="org/repo ..."
set -euo pipefail

ATOMIC_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/common.sh
. "$ATOMIC_HOME/lib/common.sh"

usage() { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

NEW_USER="" WITH_CLAUDE=1 WITH_RUST=1 AUTO_ATTACH="" SKIP_BASE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --user) NEW_USER=${2:?--user needs a name}; shift ;;
    --no-claude) WITH_CLAUDE=0 ;;
    --no-rust) WITH_RUST=0 ;;
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

Done. Open a new shell (or `exec $SHELL -l`), cd into a repo and run:  ide

  Ctrl-q then h / l   file tree / editor        Ctrl-q then /   cheat sheet
  Ctrl-q then g       git tab (lazygit)         Ctrl-q then 1/2/3  code / git / shell tabs
  Ctrl-q then d       detach (keeps running)    Ctrl-q then q   quit the session
  Every Ctrl-q key also works as Alt+key in one go (quit is Alt Shift q).

Alt keys need your local terminal to send Option as Alt (iTerm2: Left Option = Esc+,
Terminal.app: "Use Option as Meta key", Ghostty: macos-option-as-alt = left).
Claude Code: run `claude` and follow the login link, or export CLAUDE_CODE_OAUTH_TOKEN / ANTHROPIC_API_KEY.
MSG

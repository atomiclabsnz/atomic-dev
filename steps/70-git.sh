# Git identity and project checkouts. No keys are stored: use SSH agent forwarding (ssh -A) for GitHub.
if [ -n "${GIT_NAME:-}" ]; then git config --global user.name "$GIT_NAME"; fi
if [ -n "${GIT_EMAIL:-}" ]; then git config --global user.email "$GIT_EMAIL"; fi

if [ -n "${ATOMIC_REPOS:-}" ]; then
  mkdir -p "$HOME/src" "$HOME/.ssh"
  if ! ssh-keygen -F github.com >/dev/null 2>&1; then
    ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
  fi
  # shellcheck disable=SC2086  # space-separated list
  for repo in $ATOMIC_REPOS; do
    case "$repo" in
      *://*|*@*:*) url=$repo ;;
      *) url="git@github.com:$repo.git" ;;
    esac
    dest="$HOME/src/$(basename "$repo" .git)"
    if [ -d "$dest/.git" ]; then continue; fi
    say "Cloning $url"
    git clone --quiet "$url" "$dest" || warn "Could not clone $url (is your SSH agent forwarded? ssh -A)"
  done
fi

# Claude Code (native installer; it keeps itself updated), plus IDE integration
if [ "$WITH_CLAUDE" = 1 ]; then
  if have claude || [ -x "$BIN/claude" ]; then
    say "Claude Code already installed"
  else
    say "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  # Desktop notification when Claude needs you, from inside the IDE (bin/ide-notify)
  claude_settings="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  [ -f "$claude_settings" ] && cp "$claude_settings" "$claude_settings.atomic-tmp"
  rc=0; node "$ATOMIC_HOME/lib/claude-settings.js" "$claude_settings" "$BIN/ide-notify" || rc=$?
  if [ "$rc" = 0 ]; then
    if [ -f "$claude_settings.atomic-tmp" ]; then mv "$claude_settings.atomic-tmp" "$claude_settings.bak-$STAMP"; fi
    say "Added the IDE notification hook to $claude_settings"
  else
    rm -f "$claude_settings.atomic-tmp"
    [ "$rc" = 3 ] || warn "Couldn't update $claude_settings (not valid JSON?); skipped the notification hook"
  fi

  # Headless login: a token from `claude setup-token` (run on your laptop), kept out of the repo
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    mkdir -p "$CFG/atomic-dev"
    (umask 077; printf 'export CLAUDE_CODE_OAUTH_TOKEN=%q\n' "$CLAUDE_CODE_OAUTH_TOKEN" > "$CFG/atomic-dev/secrets.env")
    say "Saved CLAUDE_CODE_OAUTH_TOKEN to $CFG/atomic-dev/secrets.env (mode 600)"
  fi
fi

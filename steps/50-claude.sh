# Claude Code (native installer; it keeps itself updated)
if [ "$WITH_CLAUDE" = 1 ]; then
  if have claude || [ -x "$BIN/claude" ]; then
    say "Claude Code already installed"
  else
    say "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
  fi
fi

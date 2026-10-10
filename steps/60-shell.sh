# Hook shell/rc.sh into bash and zsh startup files
rc_line="[ -f \"$ATOMIC_HOME/shell/rc.sh\" ] && . \"$ATOMIC_HOME/shell/rc.sh\"  # atomic-dev"
rc_files=("$HOME/.bashrc")
if [ -f "$HOME/.zshrc" ] || [ "$(basename "${SHELL:-}")" = zsh ]; then rc_files+=("$HOME/.zshrc"); fi
for rc in "${rc_files[@]}"; do
  grep -qxF "$rc_line" "$rc" 2>/dev/null && continue
  say "Hooking atomic-dev into $rc"
  if grep -q '# atomic-dev$' "$rc" 2>/dev/null; then   # repo moved: replace the old line
    grep -v '# atomic-dev$' "$rc" > "$rc.atomic-tmp"; mv "$rc.atomic-tmp" "$rc"
  fi
  printf '\n%s\n' "$rc_line" >> "$rc"
done

if [ -n "$AUTO_ATTACH" ]; then
  mkdir -p "$CFG/atomic-dev"
  printf 'ATOMIC_AUTO_ATTACH=%q\n' "$AUTO_ATTACH" > "$CFG/atomic-dev/env"
  say "SSH logins will open the IDE in $AUTO_ATTACH"
fi

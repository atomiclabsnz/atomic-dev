# Symlink config/* into ~/.config (and bin/* into ~/.local/bin) so `git pull` updates this machine.
say "Linking configs into $CFG and helpers into $BIN"
# lazygit ignores ~/.config on macOS unless XDG_CONFIG_HOME is set
lazygit_dir="$CFG/lazygit"
if [ "$OS" = macos ] && [ -z "${XDG_CONFIG_HOME:-}" ]; then
  lazygit_dir="$HOME/Library/Application Support/lazygit"
fi
while IFS= read -r -d '' f; do
  rel=${f#"$ATOMIC_HOME/config/"}
  case "$rel" in
    lazygit/*) link "$f" "$lazygit_dir/${rel#lazygit/}" ;;
    *) link "$f" "$CFG/$rel" ;;
  esac
done < <(find "$ATOMIC_HOME/config" -type f -print0)
for f in "$ATOMIC_HOME"/bin/*; do link "$f" "$BIN/$(basename "$f")"; done

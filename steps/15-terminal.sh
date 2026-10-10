# macOS terminals send Option as a symbol key by default, so the IDE's Alt keys do nothing.
# For Ghostty, make the left Option key act as Alt (right Option still types symbols).
if [ "$OS" = macos ]; then
  ghostty_cfg="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  [ -f "$CFG/ghostty/config" ] && ghostty_cfg="$CFG/ghostty/config"
  if [ -d /Applications/Ghostty.app ] || [ -f "$ghostty_cfg" ]; then
    if ! grep -q '^[[:space:]]*macos-option-as-alt' "$ghostty_cfg" 2>/dev/null; then
      mkdir -p "$(dirname "$ghostty_cfg")"
      printf '\n# Added by atomic-dev: left Option acts as Alt for the IDE keys\nmacos-option-as-alt = left\n' >> "$ghostty_cfg"
      say "Ghostty: left Option now acts as Alt (reload config with Cmd+Shift+, or open a new window)"
    fi
  fi
fi

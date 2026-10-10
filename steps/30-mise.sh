# mise installs the pinned tools from config/mise/config.toml (linked by 20-config.sh)
if ! have mise && [ ! -x "$BIN/mise" ]; then
  say "Installing mise"
  curl -fsSL https://mise.run | MISE_INSTALL_PATH="$BIN/mise" sh
fi
MISE=$(command -v mise || echo "$BIN/mise")
say "Installing tools with mise (first run takes a few minutes)"
MISE_YES=1 "$MISE" install
# Later steps (and the rest of this run) need the tools on PATH
export PATH="$BIN:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"

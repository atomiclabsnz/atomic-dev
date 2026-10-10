# zjstatus: the IDE status bar (tabs + key hints that expand after Ctrl-q), see layouts/ide.kdl.
# Pinned and checksummed; its Zellij permissions are pre-granted so no prompt appears.
ZJSTATUS_VERSION=v0.25.0
ZJSTATUS_SHA256=282ceab219e56e1908c9fac33907241fe6c3e1ef7d85faab3e5f438cef87b8fe
zjstatus="$HOME/.local/share/atomic-dev/zjstatus.wasm"

sha256() { if have sha256sum; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }
if [ ! -f "$zjstatus" ] || [ "$(sha256 "$zjstatus")" != "$ZJSTATUS_SHA256" ]; then
  say "Installing zjstatus $ZJSTATUS_VERSION (status bar)"
  mkdir -p "$(dirname "$zjstatus")"
  curl -fsSL -o "$zjstatus.tmp" "https://github.com/dj95/zjstatus/releases/download/$ZJSTATUS_VERSION/zjstatus.wasm"
  [ "$(sha256 "$zjstatus.tmp")" = "$ZJSTATUS_SHA256" ] || die "zjstatus checksum mismatch"
  mv "$zjstatus.tmp" "$zjstatus"
fi

if [ "$OS" = macos ]; then zellij_cache="$HOME/Library/Caches/org.Zellij-Contributors.Zellij"
else zellij_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zellij"; fi
if ! grep -qF "\"$zjstatus\"" "$zellij_cache/permissions.kdl" 2>/dev/null; then
  mkdir -p "$zellij_cache"
  printf '"%s" {\n    ReadApplicationState\n    ChangeApplicationState\n    RunCommands\n}\n' "$zjstatus" >> "$zellij_cache/permissions.kdl"
fi

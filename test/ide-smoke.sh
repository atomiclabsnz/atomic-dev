#!/usr/bin/env bash
# Drive a real `ide` session headlessly and check the IDE behaviours that have broken before:
#   - Enter on a file in Yazi opens it in the Helix pane
#   - `h` in Yazi stops at the project root
#   - Alt q detaches (session keeps running), Alt Q quits it
# Uses this repo's config/ and bin/ through a temp XDG_CONFIG_HOME, so your own configs are untouched.
# Needs zellij, yazi, hx and `script` on PATH.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ide-smoke.XXXXXX")
tmp=$(cd "$tmp" && pwd -P)
session="ide-smoke-$$"
proj="$tmp/$session"
fails=0

cleanup() {
  pkill -f "tail -f $tmp/keys" 2>/dev/null || true
  zellij kill-session "$session" >/dev/null 2>&1 || true
  zellij delete-session "$session" >/dev/null 2>&1 || true
  [ -n "$tmp" ] && [ -d "$tmp" ] && rm -rf -- "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/config" "$proj/src"
for d in "$REPO"/config/*/; do ln -s "$d" "$tmp/config/$(basename "$d")"; done
printf 'SMOKE-MARKER-42\n' > "$proj/src/it's a file.txt"

export XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache"
export ZELLIJ_CONFIG_DIR="$tmp/config/zellij" YAZI_CONFIG_HOME="$tmp/config/yazi"
export PATH="$REPO/bin:$PATH"
unset ZELLIJ ZELLIJ_SESSION_NAME

pass() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails + 1)); }

# Run a command in a pseudo-terminal; keystrokes appended to $keys are fed to it
# (via `tail -f` rather than a fifo: macOS `script` rejects fifo stdin)
start_client() {
  local cmd="stty cols 160 rows 45; cd '$proj'; $1"
  keys="$tmp/keys.$RANDOM"; : >"$keys"
  if [ "$(uname)" = Darwin ]; then
    tail -f "$keys" | script -q /dev/null bash -c "$cmd" >>"$tmp/client.log" 2>&1 & disown
  else
    tail -f "$keys" | script -qfec "$cmd" /dev/null >>"$tmp/client.log" 2>&1 & disown
  fi
}
key()  { printf '%b' "$1" >>"$keys"; sleep 0.3; }
alt()  { key "\033$1"; }
dump() { zellij -s "$session" action dump-screen -p "$1" 2>/dev/null || true; }
# wait_for PANE REGEX [SECONDS]
wait_for() {
  local i
  for ((i = 0; i < ${3:-10} * 5; i++)); do
    dump "$1" | grep -Eq -- "$2" && return 0
    sleep 0.2
  done
  return 1
}
session_state() {
  zellij list-sessions --no-formatting 2>/dev/null | awk -v s="$session" '$1 == s { print (/EXITED/ ? "exited" : "running"); f=1 } END { if (!f) print "gone" }'
}

echo "ide smoke test (session $session)"
start_client "ide"
for _ in $(seq 50); do [ "$(session_state)" = running ] && break; sleep 0.2; done
[ "$(session_state)" = running ] || { fail "session did not start"; tail -c 2000 "$tmp/client.log" | tr -d '\033' | tail -20; exit 1; }

# Find the Yazi and Helix panes by what they show (pane ids depend on layout order)
find_pane() {
  local i p
  for ((i = 0; i < 50; i++)); do
    for p in terminal_{0..5}; do dump "$p" | grep -Eq -- "$1" && { echo "$p"; return; }; done
    sleep 0.3
  done
  return 1
}
yazi=$(find_pane "/$session *$") && helix=$(find_pane '\[scratch\]') || {
  fail "Yazi/Helix did not start"
  for p in terminal_{0..3}; do echo "-- $p"; dump "$p" | grep -v '^[[:space:]]*$'; done
  exit 1
}
pass "session started with Yazi and Helix"

alt h                                   # focus the file tree
key h                                   # try to go above the project root
sleep 0.5
if dump "$yazi" | head -1 | sed 's/[[:space:]]*$//' | grep -q "/$session\$"; then pass "h at project root stays put"; else fail "h left the project root"; dump "$yazi"; fi

key l                                   # into src/
wait_for "$yazi" "it's a file" 5 || true
key '\r'                                # open the hovered file
if wait_for "$helix" 'SMOKE-MARKER-42' 5; then pass "Enter in Yazi opens the file in Helix"
else fail "file did not open in Helix"; dump "$helix"; cat "$tmp/cache/atomic-dev/yazi-to-helix.log" 2>/dev/null || true; fi

alt q                                   # detach
sleep 1
[ "$(session_state)" = running ] && pass "Alt q detaches, session keeps running" || fail "after Alt q session is $(session_state)"

stamp="$tmp/cache/atomic-dev/sessions/$session"
yazi_dir() { dump "$yazi" | head -1 | sed 's/[[:space:]]*$//'; }

start_client "ide"                      # config unchanged: re-attach to the same session
sleep 2
if yazi_dir | grep -q '/src$'; then pass "re-attaches when the config is unchanged"
else fail "unchanged config did not re-attach"; yazi_dir; fi
alt q
sleep 1

echo stale > "$stamp"                   # pretend the config changed since the session started
start_client "ide"
sleep 1
key '\r'                                # accept the default: restart
sleep 1
if yazi=$(find_pane "/$session *$") && [ "$(cat "$stamp")" != stale ] && [ "$(session_state)" = running ]; then
  pass "stale session is restarted with the new config"
else fail "stale session was not restarted"; tail -c 600 "$tmp/client.log" | tr -d '\033'; fi

alt Q                                   # quit
for _ in $(seq 25); do [ "$(session_state)" = running ] || break; sleep 0.2; done
[ "$(session_state)" != running ] && pass "Alt Q quits the session" || fail "session still running after Alt Q"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

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
# On Linux Zellij keeps plugin permissions under $XDG_CACHE_HOME, so carry over the grant
# for the status bar plugin that install.sh made (macOS always uses ~/Library/Caches)
if [ -f "$HOME/.cache/zellij/permissions.kdl" ]; then
  mkdir -p "$XDG_CACHE_HOME/zellij"; cp "$HOME/.cache/zellij/permissions.kdl" "$XDG_CACHE_HOME/zellij/"
fi
# A stand-in for Claude Code, so the claude tab doesn't start (or need) the real thing
mkdir -p "$tmp/fakebin"
printf '#!/bin/sh\necho FAKE-CLAUDE-READY\nexec sleep 100000\n' > "$tmp/fakebin/claude"
chmod +x "$tmp/fakebin/claude"
export PATH="$REPO/bin:$tmp/fakebin:$PATH"
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
# dump-screen can hang if the session has died, so give it a few seconds at most
dump() {
  local out="$tmp/dump.$RANDOM" pid i
  zellij -s "$session" action dump-screen -p "$1" >"$out" 2>/dev/null &
  pid=$!
  for i in $(seq 15); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  kill "$pid" 2>/dev/null || true
  cat "$out"; rm -f "$out"
}
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

key '\021'; key h                       # Ctrl-q h, sent as iTerm2 does (0x11): focus the file tree
key h                                   # try to go above the project root
sleep 1                                 # give h time to act, then expect the root header
if wait_for "$yazi" "/$session *\$" 2 && dump "$yazi" | grep -q ' src'; then pass "h at project root stays put"
else fail "h left the project root"; dump "$yazi"; fi

key l                                   # into src/
wait_for "$yazi" "it's a file" 5 || true
key '\r'                                # open the hovered file
if wait_for "$helix" 'SMOKE-MARKER-42' 5; then pass "Enter in Yazi opens the file in Helix"
else fail "file did not open in Helix"; dump "$helix"; cat "$tmp/cache/atomic-dev/yazi-to-helix.log" 2>/dev/null || true; fi

# h/l must only move within the tab: from a terminal opened below the editor (rightmost pane),
# Ctrl-q l used to jump to the git tab
key '\021'; key t                       # Ctrl-q t: terminal below the editor
sleep 3                                 # let its shell start
key '\021'; key l                       # Ctrl-q l at the right edge: should stay put
# shellcheck disable=SC2016  # typed into the pane's shell, which computes 42
key 'echo STILL-$((6 * 7))\r'
still_here=no
for _ in $(seq 25); do
  zellij -s "$session" action dump-screen 2>/dev/null | grep -q 'STILL-42' && { still_here=yes; break; }
  sleep 0.2
done
if [ "$still_here" = yes ]; then pass "h/l stay within the tab at the edges"
else fail "Ctrl-q l at the right edge left the tab"; fi
zellij -s "$session" action close-pane 2>/dev/null || true   # remove the extra terminal
zellij -s "$session" action go-to-tab 1 2>/dev/null || true

alt q                                   # detach
sleep 1
[ "$(session_state)" = running ] && pass "Alt q detaches, session keeps running" || fail "after Alt q session is $(session_state)"

stamp="$tmp/cache/atomic-dev/sessions/$session"
yazi_dir() { dump "$yazi" | head -1 | sed 's/[[:space:]]*$//'; }

start_client "ide"                      # config unchanged: re-attach to the same session
sleep 2
if yazi_dir | grep -q '/src$'; then pass "re-attaches when the config is unchanged"
else fail "unchanged config did not re-attach"; yazi_dir; fi
# Ctrl-q as Ghostty sends it (kitty keyboard protocol, which Zellij turns on)
ctrl_q='\033[113;5u'
key "$ctrl_q"; key "$ctrl_q"            # Ctrl-q twice cancels, must not quit
sleep 0.5
[ "$(session_state)" = running ] && pass "Ctrl-q Ctrl-q cancels without quitting" || fail "Ctrl-q Ctrl-q quit the session"
log_size=$(wc -c < "$tmp/client.log")
key "$ctrl_q"; key d                    # Ctrl-q d: detach
sleep 1
if [ "$(session_state)" = running ] && tail -c +"$((log_size + 1))" "$tmp/client.log" | grep -q 'Bye from Zellij'; then
  pass "Ctrl-q d detaches"; else fail "Ctrl-q d did not detach (session $(session_state))"; fi
if sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$tmp/client.log" | grep -Eq 'ide-files|editor'; then fail "pane frames show titles"
else pass "pane frames have no titles"; fi

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

# Starting again after a quit gives a fresh session, not panes paused at "press ENTER"
start_client "ide"
if helix=$(find_pane '\[scratch\]') && yazi=$(find_pane "/$session *$") && [ "$(session_state)" = running ]; then
  pass "ide after quit starts fresh (no ENTER prompts)"
else fail "ide after quit did not start cleanly"; for p in terminal_{0..3}; do echo "-- $p"; dump "$p" | grep -v '^[[:space:]]*$' | head -5; done; fi

key "$ctrl_q"; key g                    # Ctrl-q g: git tab
sleep 1
if zellij -s "$session" action dump-screen 2>/dev/null | grep -qi 'git'; then pass "Ctrl-q g shows the git tab"
else fail "Ctrl-q g did not show lazygit"; fi
key "$ctrl_q"; key 1                    # back to the code tab (Helix focused)
key ':q\r'                              # quit Helix by habit: the pane should restart it
sleep 3
if wait_for "$helix" '\[scratch\]' 5 && ! dump "$helix" | grep -qi 'enter'; then pass "quitting Helix restarts it instead of leaving a dead pane"
else fail "Helix pane did not come back"; dump "$helix"; fi

log_size=$(wc -c < "$tmp/client.log")
key "$ctrl_q"                           # status bar expands to the full key list
bar_expanded=no
for _ in $(seq 15); do
  tail -c +"$((log_size + 1))" "$tmp/client.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -q 'd detach' && { bar_expanded=yes; break; }
  sleep 0.2
done
if [ "$bar_expanded" = yes ]; then
  pass "Ctrl-q shows the key list in the status bar"
else
  fail "status bar didn't show keys after Ctrl-q"
  tail -c 3000 "$tmp/client.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | tr -s ' ' | tail -c 800
fi
key c                                   # ...then c: Claude tab
claude_shown=no
for _ in $(seq 25); do
  zellij -s "$session" action dump-screen 2>/dev/null | grep -q 'FAKE-CLAUDE-READY' && { claude_shown=yes; break; }
  sleep 0.2
done
if [ "$claude_shown" = yes ]; then pass "Ctrl-q c shows the claude tab"
else fail "Ctrl-q c did not show Claude"; fi

log_size=$(wc -c < "$tmp/client.log")
zellij -s "$session" action new-pane -- bash -c "printf '{\"message\":\"Claude needs your permission\"}' | IDE_ROOT='$proj' ide-notify; sleep 2" >/dev/null
sleep 1.5
if tail -c +"$((log_size + 1))" "$tmp/client.log" | grep -q "]9;Claude · $session: Claude needs your permission"; then
  pass "ide-notify sends a desktop notification through Zellij"; else fail "no OSC 9 notification reached the terminal"; fi
zellij -s "$session" action go-to-tab 1 2>/dev/null || true

key "$ctrl_q"; key q                    # Ctrl-q q: quit
for _ in $(seq 25); do [ "$(session_state)" = running ] || break; sleep 0.2; done
[ "$(session_state)" != running ] && pass "Ctrl-q q quits" || fail "session still running after Ctrl-q q"

# Project picker: lists projects under $IDE_PROJECTS; typing filters, Enter opens
start_client "IDE_PROJECTS='$tmp' ide -p"
sleep 1.5
key "$session"; sleep 0.5; key '\r'
for _ in $(seq 50); do [ "$(session_state)" = running ] && break; sleep 0.2; done
if [ "$(session_state)" = running ]; then pass "ide -p picks a project and opens it"
else fail "ide -p did not open the project"; tail -c 1500 "$tmp/client.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | tr -s ' \n' | tail -c 600; fi
key "$ctrl_q"; key q

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

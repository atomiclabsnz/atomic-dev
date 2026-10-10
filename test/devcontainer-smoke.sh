#!/usr/bin/env bash
# Open a throwaway dev container project with `ide` and check the IDE runs inside the container:
# Yazi and Helix start, Helix's Python language server is found, the shell is the container's,
# and detaching leaves the container running. Needs Docker and the devcontainer CLI.
# Uses its own tools volume (removed afterwards), so it also exercises a first-time install.
#   test/devcontainer-smoke.sh [image|compose]   plain image (default) or Docker Compose dev container
#   ATOMIC_TEST_DEVCONTAINER_IMAGE  image to use (default: mcr.microsoft.com/devcontainers/python:3.13-trixie)
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
kind=${1:-image}
image="${ATOMIC_TEST_DEVCONTAINER_IMAGE:-mcr.microsoft.com/devcontainers/python:3.13-trixie}"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ide-dc.XXXXXX")
tmp=$(cd "$tmp" && pwd -P)
proj="$tmp/dc-smoke-$$"
export ATOMIC_DEVCONTAINER_VOLUME="atomic-dev-test-$$"
export PATH="$REPO/bin:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"
unset ZELLIJ ZELLIJ_SESSION_NAME
fails=0
container=""

cleanup() {
  pkill -f "tail -f $tmp/keys" 2>/dev/null || true
  if [ -n "$container" ]; then
    compose_project=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null || true)
    docker rm -f "$container" >/dev/null 2>&1
    [ -n "$compose_project" ] && docker network rm "${compose_project}_default" >/dev/null 2>&1
  fi
  docker volume rm "$ATOMIC_DEVCONTAINER_VOLUME" >/dev/null 2>&1 || true
  [ -n "$tmp" ] && [ -d "$tmp" ] && rm -rf -- "$tmp"
}
trap cleanup EXIT

pass() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails + 1)); }

mkdir -p "$proj/.devcontainer"
if [ "$kind" = compose ]; then
  cat > "$proj/.devcontainer/docker-compose.yml" <<EOF
services:
  app:
    image: $image
    command: sleep infinity
    volumes:
      - ..:/workspaces/$(basename "$proj"):cached
EOF
  printf '{ "dockerComposeFile": "./docker-compose.yml", "service": "app", "workspaceFolder": "/workspaces/%s", "remoteUser": "vscode" }\n' \
    "$(basename "$proj")" > "$proj/.devcontainer/devcontainer.json"
else
  printf '{ "image": "%s" }\n' "$image" > "$proj/.devcontainer/devcontainer.json"
fi
printf 'print("hello")\n' > "$proj/hello.py"

# `ide` in a pseudo-terminal, keystrokes appended to $tmp/keys (see test/ide-smoke.sh)
: > "$tmp/keys"
if [ "$(uname)" = Darwin ]; then
  tail -f "$tmp/keys" | script -q /dev/null bash -c "stty cols 160 rows 45; cd '$proj'; ide" >"$tmp/client.log" 2>&1 & disown
else
  tail -f "$tmp/keys" | script -qfec "stty cols 160 rows 45; cd '$proj'; ide" /dev/null >"$tmp/client.log" 2>&1 & disown
fi
key() { printf '%b' "$1" >>"$tmp/keys"; sleep 0.3; }

# Run a command as the container's user with the atomic-dev environment
in_container() {
  docker exec -u "$user" "$container" bash -c ". /opt/atomic-dev/shell/rc.sh; $1"
}

echo "dev container smoke test ($kind, $image)"
for _ in $(seq 150); do
  container=$(docker ps -q --filter "label=devcontainer.local_folder=$proj" | head -n 1)
  [ -n "$container" ] && break
  grep -qE 'xx|missing|Can.t reach|needed for|failed' "$tmp/client.log" && break   # ide gave up
  sleep 2
done
[ -n "$container" ] || { fail "dev container did not start"; tail -c 1500 "$tmp/client.log"; exit 1; }
pass "dev container started"

user=$(docker inspect -f '{{index .Config.Labels "devcontainer.metadata"}}' "$container" |
  sed -n 's/.*"remoteUser":"\([^"]*\)".*/\1/p' | tail -n 1)
user=${user:-root}
session=$(basename "$proj" | tr -c 'A-Za-z0-9_\n-' '-')

# First start installs the tools into the fresh volume, which takes a few minutes
started=no
for _ in $(seq 300); do
  if in_container "zellij list-sessions --short 2>/dev/null" 2>/dev/null | grep -qx "$session"; then started=yes; break; fi
  sleep 2
done
if [ "$started" = yes ]; then pass "IDE session running inside the container"
else
  fail "IDE session did not start in the container"
  tail -n 30 "${XDG_CACHE_HOME:-$HOME/.cache}/atomic-dev/devcontainer-$(basename "$proj").log" 2>/dev/null || true
  exit 1
fi

dump() { in_container "zellij -s $session action dump-screen -p $1" 2>/dev/null || true; }
found=no
for _ in $(seq 30); do
  if dump terminal_0 | grep -q 'hello.py' && dump terminal_1 | grep -q '\[scratch\]'; then found=yes; break; fi
  sleep 1
done
[ "$found" = yes ] && pass "Yazi shows the project and Helix is open" || fail "Yazi/Helix not showing in the container"

if in_container "hx --health python" | sed 's/\x1b\[[0-9;]*m//g' | grep -q '✓ basedpyright'; then
  pass "Helix finds the Python language server inside the container"
else fail "Helix can't find basedpyright in the container"; fi
if in_container "command -v python3" | grep -qv '^/opt/atomic-dev-tools'; then
  pass "python3 is the container's own ($(in_container 'python3 --version'))"
else fail "python3 isn't the container's"; fi

host_email=$(git config --global user.email 2>/dev/null || true)
if [ -z "$host_email" ] || [ "$(in_container 'git config --global user.email')" = "$host_email" ]; then
  pass "git identity carried into the container"; else fail "git identity missing in the container"; fi
if [ "$(uname)" != Darwin ] && [ ! -S "${SSH_AUTH_SOCK:-}" ]; then
  echo "  skip SSH agent check (no agent on this machine)"
elif in_container 'test -S /tmp/atomic-ssh-agent.sock'; then pass "SSH agent socket available in the container"
else fail "no SSH agent socket in the container"; fi

key '\033[113;5u'; key d                # Ctrl-q d: detach
sleep 2
if docker ps -q --no-trunc | grep -q "^$container" && in_container "zellij list-sessions --short" | grep -qx "$session"; then
  pass "Ctrl-q d detaches; container and session keep running"
else fail "detach stopped the container or session"; fi

# Running ide again re-attaches to the same container and session, quickly
: > "$tmp/keys"
SECONDS=0
if [ "$(uname)" = Darwin ]; then
  tail -f "$tmp/keys" | script -q /dev/null bash -c "stty cols 160 rows 45; cd '$proj'; ide" >"$tmp/client2.log" 2>&1 & disown
else
  tail -f "$tmp/keys" | script -qfec "stty cols 160 rows 45; cd '$proj'; ide" /dev/null >"$tmp/client2.log" 2>&1 & disown
fi
attached=no
for _ in $(seq 60); do
  in_container "zellij -s $session action list-clients 2>/dev/null" | grep -q '^[0-9]' && { attached=yes; break; }
  sleep 1
done
if [ "$attached" = yes ] && [ "$(docker ps -q --filter "label=devcontainer.local_folder=$proj" | wc -l)" -eq 1 ]; then
  pass "ide again re-attaches to the same container (${SECONDS}s)"
else fail "ide again did not re-attach"; tail -c 800 "$tmp/client2.log"; fi
key '\033[113;5u'; key d

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }

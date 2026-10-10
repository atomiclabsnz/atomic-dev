#!/usr/bin/env bash
# Runs inside a fresh container as root (see test/docker.sh). Repo is mounted read-only at /src.
set -euo pipefail
# Docker (esp. under emulation) can't run pacman's download sandbox; real Arch hosts are fine
if [ -f /etc/pacman.conf ]; then sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf; fi
mkdir -p /root/.atomic-dev && cp -a /src/. /root/.atomic-dev/
bash /root/.atomic-dev/install.sh --user dev

echo "==> Second run (should change nothing)"
sudo -u dev -H bash /home/dev/.atomic-dev/install.sh --skip-base

echo "==> Checks"
sudo -u dev -H bash <<'CHECKS'
set -uo pipefail
. ~/.atomic-dev/shell/rc.sh
fails=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; fails=$((fails+1)); fi; }

for c in hx zellij yazi lazygit rg fd fzf gh uv ruff node cargo claude; do
  check "$c runs" "$c --version"
done
for pair in python:basedpyright python:ruff rust:rust-analyzer typescript:typescript-language-server \
            toml:taplo markdown:marksman yaml:yaml-language-server; do
  check "helix finds ${pair#*:} for ${pair%%:*}" "hx --health ${pair%%:*} | sed 's/\x1b\[[0-9;]*m//g' | grep -q '✓ ${pair#*:}'"
done
check "no backups made on a fresh machine" "[ -z \"\$(find ~ -name '*.bak-*' -print -quit)\" ]"
check "rc hook added exactly once" "[ \"\$(grep -c '# atomic-dev\$' ~/.bashrc)\" = 1 ]"
check "configs are symlinks into the repo" "[ \"\$(readlink ~/.config/zellij/config.kdl)\" = ~/.atomic-dev/config/zellij/config.kdl ]"
check "git identity set" "[ \"\$(git config --global user.email)\" = smoke@example.com ]"

bash ~/.atomic-dev/test/ide-smoke.sh || fails=$((fails+1))
exit "$fails"
CHECKS

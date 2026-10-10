# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A one-command setup that gives any fresh server (VPS, cloud VM, spot instance) or Mac the same dev environment: a terminal IDE (Zellij + Yazi + Helix + Lazygit), Python/Rust/Node toolchains and Claude Code. Targets are Ubuntu/Debian (primary), Arch and macOS. Servers are disposable, so the installer must be fast and idempotent: re-running it is the update path. See README.md for usage.

## Commands

- Lint: `shellcheck -x bootstrap.sh install.sh lib/*.sh steps/*.sh shell/rc.sh $(grep -l "^#!.*bash" bin/*) test/*.sh` (`bin/ide-keytest` is Python). `.shellcheckrc` disables SC2034 because variables are shared with sourced steps. Without a local shellcheck, use `docker run --rm -v "$PWD":/mnt -w /mnt koalaman/shellcheck:stable -x ...`.
- IDE behaviour test (uses this repo's config, leaves your own untouched): `test/ide-smoke.sh`
- Dev container test (needs Docker and the devcontainer CLI; uses its own tools volume): `test/devcontainer-smoke.sh`, about 35s
- Full install test in containers: `test/docker.sh` (all images, roughly 3 min each; Arch runs under amd64 emulation) or `test/docker.sh ubuntu:24.04`.
- Don't run `install.sh` on the host just to test. It modifies the real `~/.config`, `~/.bashrc` / `~/.zshrc` and `~/.local/bin`.

## Architecture

- `bootstrap.sh` (the curl|bash entry point) clones or updates the repo into `~/.atomic-dev`, then execs `install.sh`. `install.sh` parses options and **sources** `steps/*.sh` in lexical order, so steps share variables (`OS`, `ATOMIC_HOME`, `BIN`, `CFG`, the option flags) and helpers from `lib/common.sh` (`say`, `link`, `backup`, `as_root`, `have`).
- Because steps are sourced under `set -e`, guard them with `if` blocks. A trailing `[ … ] && …` can make the `.` fail.
- macOS runs these scripts with `/bin/bash` 3.2: no associative arrays, and expanding an empty array under `set -u` fails.
- `00-user.sh` (`--user NAME`, as root) installs base packages, creates the user, copies the repo to that user's `~/.atomic-dev`, then re-execs `install.sh --skip-base` as that user.
- Only the base packages come from apt/pacman/brew (`10-base.sh`). Everything else is pinned in `config/mise/config.toml` and installed by mise, so every machine gets identical versions. Rust is the exception: rustup, so rust-analyzer matches the toolchain.
- Prebuilt Linux binaries must run on the oldest supported distro (Debian 12, glibc 2.36). Yazi's glibc build needs 2.39, so it uses the `github:` backend pinned to the musl asset. Run `test/docker.sh debian:12` after bumping tool versions.
- `20-config.sh` **symlinks** every file under `config/` into `$XDG_CONFIG_HOME` (lazygit goes to `~/Library/Application Support/lazygit` on macOS), and `bin/*` into `~/.local/bin`. Existing files are moved to `*.bak-<timestamp>`. Adding a config file only needs the file; no installer change.
- `shell/rc.sh` is sourced from bash/zsh rc files. It puts the **mise shims** on PATH rather than using `mise activate`, so tools resolve in Zellij command panes, Yazi openers and non-interactive shells.

## Coupled pieces (change together)

- Every IDE action has two bindings in `config/zellij/config.kdl`: `Alt`+key in `shared`, and `Ctrl-q` then a plain key in `normal` (each returns to locked mode). h/l use `MoveFocus`, not `MoveFocusOrTab`, so at the edge of a tab they stay put instead of jumping to another tab. The Ctrl-q route exists because macOS terminals don't send Alt by default (`steps/15-terminal.sh` fixes that for Ghostty). The leader is Ctrl-q: Zellij's default Ctrl-g is grabbed system-wide by Chrome's Gemini launcher on macOS. Ctrl-] was tried and dropped, because Zellij ignores the legacy byte (0x1d) that iTerm2 sends. Ctrl+letter arrives reliably from every terminal. Ctrl-g stays as a fallback, and `normal` rebinds Ctrl-q to cancel, overriding Zellij's default Ctrl-q = quit. `bin/ide-keytest` shows what a terminal actually sends.
- Zellij `keybinds` in `config/zellij/config.kdl` ↔ the zjstatus `mode_*` hint strings in `config/zellij/layouts/ide.kdl` ↔ `config/ide/cheatsheet.txt` ↔ the summary at the end of `install.sh` ↔ README. Tab numbers (1 code, 2 claude, 3 git, 4 shell) are hard-coded in the `GoToTab` bindings.
- The status bar is the zjstatus plugin, loaded from `~/.local/share/atomic-dev/zjstatus.wasm`. `steps/25-zjstatus.sh` downloads it (version and sha256 pinned there) and pre-grants its permissions in Zellij's `permissions.kdl`; without that, Zellij shows a permission prompt in the bar. `test/ide-smoke.sh` uses the installed copy, so run the installer (or that step) first.
- `bin/ide` starts the session with layout `ide` (`config/zellij/layouts/ide.kdl`). It also exports `IDE_ROOT`, which the Yazi plugin `config/yazi/plugins/project-root.yazi` uses to stop `h` at the project folder; `config/yazi/keymap.toml` binds it.
- `bin/ide` records a checksum of `config/` + `bin/` in `~/.cache/atomic-dev/sessions/<name>` when it creates a session. On re-attach, a mismatch (or no record) prompts a restart, since a running Zellij session keeps its old layout, panes and env. This depends on `~/.local/bin/ide` being a symlink into the repo.
- Opening a file from Yazi: an opener in `yazi.toml` runs `yazi-to-helix %s`, which uses `zellij action` to move focus right and type `:open '<path>'` into Helix. This relies on the layout putting the file tree directly left of the editor.
  - Yazi 26 dropped `$@` in openers; use `%s`, which Yazi quotes itself.
  - Keep the short sleep between Esc and `:`, or Helix reads the pair as Alt+`:`.
- Layout panes run their program through `bin/ide-pane`, which restarts it on exit, so `:q` in Helix or `q` in lazygit never leaves a dead "press ENTER" pane. `session_serialization false` plus `bin/ide` deleting EXITED sessions stops quit sessions from being resurrected with every pane paused. Lazygit lives in the git tab only; `g` switches to that tab, so there's no popup to close.
- Claude integration:
  - The claude tab runs `bin/ide-claude`, which tries `claude --continue` on first launch.
  - `steps/50-claude.sh` merges a `Notification` hook into `~/.claude/settings.json` with `lib/claude-settings.js`, run by node from mise. It keeps the user's other settings and makes a backup.
  - The hook, `bin/ide-notify`, only acts inside Zellij. It writes OSC 9 to the tty; Zellij forwards OSC 9 to the outer terminal, but not OSC 777 or a bare BEL.
  - `CLAUDE_CODE_OAUTH_TOKEN` given at install time goes to `~/.config/atomic-dev/secrets.env` (mode 600), which `shell/rc.sh` sources.
  - The smoke test puts a fake `claude` first on PATH.
- `bin/ide` with no args in `$HOME` (or `-p`) opens an fzf project picker. It reads session folders from the `<name>.dir` files written next to the session checksums.
- `.github/workflows/`: `ci.yml` runs shellcheck and `test/docker.sh` for each distro. `bump-tools.yml` bumps `config/mise/config.toml` weekly into a PR. Node only moves within its major there; mise needs node installed before the `npm:` tools, so the job bumps it first.
- Dev containers:
  - `bin/ide` hands projects with `.devcontainer/devcontainer.json` to `bin/ide-devcontainer`.
  - That script runs `devcontainer up` with two extra mounts. This repo goes at `/opt/atomic-dev` (read-only), and the shared `atomic-dev-tools` volume goes at `/opt/atomic-dev-tools`.
  - It symlinks the container user's `~/.local/share/{mise,claude}` into the volume, runs `install.sh --container` (minimal base packages, no Rust or Docker), then execs `ide` inside.
  - The mounts only apply when a container is created, hence `ide --rebuild`.
  - `ATOMIC_IN_DEVCONTAINER=1` stops `ide` recursing inside the container.
  - On macOS the SSH agent comes from `/run/host-services/ssh-auth.sock` (OrbStack and Docker Desktop).
- The file-tree pane runs `bin/ide-files`, not `yazi` directly: on Linux, Yazi exits if it starts before Zellij has sized the pane.
- The language servers in `config/mise/config.toml` must match what `config/helix/languages.toml` and Helix's defaults expect. `test/in-container.sh` checks them with `hx --health`.
- `bin/ide` uses `tr -c 'A-Za-z0-9_\n-'`. The `-` must stay last, or GNU tr treats it as a range.

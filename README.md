# atomic-dev

One command turns a fresh server (VPS, cloud VM, spot instance) or a Mac into the same terminal dev environment:

- **IDE:** Zellij (layout and sessions) + Yazi (file tree) + Helix (editor/LSP) + Lazygit
- **Languages:** Python (uv, ruff, basedpyright), Rust (rustup, rust-analyzer, clippy), Node/TypeScript
- **Claude Code**

Servers are treated as disposable: push your work often, and rebuild with the one-liner.

## Quick start

On a fresh Ubuntu/Debian or Arch server, as root:

```sh
curl -fsSL https://raw.githubusercontent.com/CHANGE-ME/atomic-dev/main/bootstrap.sh \
  | GIT_NAME="Your Name" GIT_EMAIL="you@example.com" bash -s -- --user dev
```

Then connect as the new user and open a project:

```sh
ssh -A dev@server      # -A forwards your SSH agent, so git push works without keys on the box
cd ~/src/myproject && ide
```

On a Mac, or as an existing non-root user, drop `--user`. To provision hands-off, paste the same command into cloud-init `runcmd`.

Re-running the command is safe, and it's also how you update: it pulls the repo and re-applies everything.

### Options

| Option | |
|---|---|
| `--user NAME` | Run as root. Creates a passwordless-sudo user with root's `authorized_keys` and installs everything for that user. |
| `--no-claude`, `--no-rust` | Skip Claude Code or Rust. |
| `--auto-attach DIR` | Interactive SSH logins go straight into `ide DIR`. |

| Environment variable | |
|---|---|
| `GIT_NAME`, `GIT_EMAIL` | Git identity. |
| `ATOMIC_REPOS="org/a org/b"` | Clone these into `~/src` (GitHub SSH, or full URLs). |
| `ATOMIC_REF` | Branch or tag of this repo to install (default `main`). |
| `GITHUB_TOKEN` | Optional. Avoids GitHub API rate limits when mise downloads tools. |

### Claude Code login on a server

Run `claude` and open the login link it prints. Alternatively, export `CLAUDE_CODE_OAUTH_TOKEN` (create one locally with `claude setup-token`) or `ANTHROPIC_API_KEY`. The installer never stores secrets.

## Using the IDE

`ide [dir]` opens a Zellij session named after the folder, or re-attaches to it if one exists. Sessions survive SSH disconnects. If the atomic-dev config has changed since that session started, `ide` offers to restart it, because a re-attached session keeps its old setup.

| Key | |
|---|---|
| `Alt h` / `Alt l` | file tree / editor |
| `Alt 1` `2` `3` | code / git / shell tabs |
| `Alt g` | lazygit popup |
| `Alt t` | terminal below |
| `Alt /` | full cheat sheet |
| `Alt q` | detach (the session keeps running) |
| `Alt Q` | quit the session |
| `Ctrl-g` | unlock Zellij's own menus |

In the file tree, `Enter` opens a file in Helix, and `h` stops at the project folder.

**On macOS, the Alt keys only work if your terminal sends Option as Meta:**
- iTerm2: Profiles → Keys → Left Option = Esc+
- Terminal.app: Settings → Profiles → Keyboard → "Use Option as Meta key"
- Ghostty: `macos-option-as-alt = true`

**Fonts:** install a Nerd Font (for example JetBrainsMono Nerd Font) on the machine your terminal runs on. The installer adds it automatically on a Mac.

## Layout

```
bootstrap.sh        curl|bash entry: clone/update into ~/.atomic-dev, run install.sh
install.sh          parse options, run steps/*.sh in order
steps/              00-user 10-base 20-config 30-mise 40-rust 50-claude 60-shell 70-git
config/             symlinked into ~/.config (tool versions: config/mise/config.toml)
bin/                symlinked into ~/.local/bin (ide, helpers)
shell/rc.sh         sourced from ~/.bashrc / ~/.zshrc
test/               ide-smoke.sh (IDE behaviour), docker.sh (full install per distro)
```

To upgrade tools, bump the versions in `config/mise/config.toml` (`mise outdated` lists newer ones) and re-run the installer.

## Testing

```sh
test/ide-smoke.sh            # drives a real headless IDE session using this repo's config
test/docker.sh               # full install in ubuntu:24.04, debian:12 and archlinux, then checks
test/docker.sh ubuntu:24.04  # a single image
```

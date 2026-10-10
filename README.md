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
ide                    # in your home folder: pick a project from ~/src and running sessions
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
| `CLAUDE_CODE_OAUTH_TOKEN` | Optional. Logs Claude Code in without a browser; see below. |

### Claude Code login on a server

To skip the browser login on every new server:
1. On your laptop, run `claude setup-token` once to create a long-lived token.
2. Pass the token to the installer: `CLAUDE_CODE_OAUTH_TOKEN=... bash -s -- --user dev`. Put the variable on the `bash` side of the pipe, like the other variables in Quick start.

The installer saves it to `~/.config/atomic-dev/secrets.env` (readable only by you), and your shell loads it from there. Without a token, run `claude` and open the login link it prints.

Your shell history keeps that command line, token included, so clear it afterwards (`history -c` in bash).

### Faster servers: snapshot after the first install

In our container tests a first install took 60–90 seconds, mostly downloading tools, and a re-run on an installed machine took under 5 seconds. The download time depends on the server's network. For spot instances:
1. Install once.
2. Save a disk snapshot or image with your cloud provider.
3. Start new instances from that image, and run the same one-liner at boot (for example in cloud-init) to pick up the latest config.

## Using the IDE

`ide [dir]` opens a Zellij session named after the folder, or re-attaches to it if one exists. Sessions survive SSH disconnects.
- `ide` in your home folder, or `ide -p` anywhere, lets you pick a project: running sessions first, then folders in `~/src` (set `IDE_PROJECTS` to use another folder).
- If the atomic-dev config has changed since a session started, `ide` offers to restart it, because a re-attached session keeps its old setup.

Each session has four tabs:
1. **code:** file tree (Yazi) and editor (Helix)
2. **claude:** Claude Code in the project folder. It resumes your last conversation in that folder when the IDE starts.
3. **git:** lazygit
4. **shell:** a plain shell

The bar at the bottom shows the tabs. Press `Ctrl-q` and it lists every key.

When Claude needs you (a permission prompt, or waiting for input), you get a desktop notification, even over SSH. It works in Ghostty and iTerm2. On macOS, the first notification may ask for permission.

Press `Ctrl-q`, then a key. It works in any terminal. `Ctrl-g` (Zellij's usual key) also works wherever nothing else grabs it; Chrome's Gemini launcher takes it on macOS. If your terminal sends Alt, `Alt`+key does the same thing in one go.

| `Ctrl-q`, then | Alt version | |
|---|---|---|
| `h` / `l` | `Alt h` / `Alt l` | file tree / editor (clicking a pane also works) |
| `1` `2` `3` `4` | `Alt 1` … `4` | code / claude / git / shell tabs |
| `c` | `Alt 2` | claude tab |
| `g` | `Alt g` | git tab |
| `t` | `Alt t` | terminal below |
| `/` | `Alt /` | full cheat sheet |
| `d` | `Alt d` | detach (the session keeps running) |
| `q` | `Alt Shift q` | quit the session |
| `Esc` | | cancel |

In the file tree, `Enter` opens a file in Helix, and `h` stops at the project folder.

**On macOS, the Alt versions only work if your terminal sends Option as Alt.** The installer sets this up for Ghostty (`macos-option-as-alt = left`). For other terminals:
- iTerm2: Profiles → Keys → Left Option = Esc+
- Terminal.app: Settings → Profiles → Keyboard → "Use Option as Meta key"

**Fonts:** install a Nerd Font (for example JetBrainsMono Nerd Font) on the machine your terminal runs on. The installer adds it automatically on a Mac.

## Layout

```
bootstrap.sh        curl|bash entry: clone/update into ~/.atomic-dev, run install.sh
install.sh          parse options, run steps/*.sh in order
steps/              00-user 10-base 15-terminal 20-config 25-zjstatus 30-mise 40-rust 50-claude 60-shell 70-git
config/             symlinked into ~/.config (tool versions: config/mise/config.toml)
bin/                symlinked into ~/.local/bin (ide, helpers)
shell/rc.sh         sourced from ~/.bashrc / ~/.zshrc
test/               ide-smoke.sh (IDE behaviour), docker.sh (full install per distro)
```

To upgrade tools, bump the versions in `config/mise/config.toml` (`mise outdated` lists newer ones) and re-run the installer. On GitHub, a weekly workflow (`.github/workflows/bump-tools.yml`) opens that pull request for you, and CI runs the full install test on it.

## Testing

```sh
test/ide-smoke.sh            # drives a real headless IDE session using this repo's config
test/docker.sh               # full install in ubuntu:24.04, debian:12 and archlinux, then checks
test/docker.sh ubuntu:24.04  # a single image
```

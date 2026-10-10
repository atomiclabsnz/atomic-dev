# atomic-dev shell setup, sourced from ~/.bashrc / ~/.zshrc (hook added by install.sh)

_atomic_path() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
# mise shims (not `mise activate`) so tools also resolve in Zellij panes, Yazi openers and ssh commands
_atomic_path "${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"
[ -d "$HOME/.cargo/bin" ] && _atomic_path "$HOME/.cargo/bin"
_atomic_path "$HOME/.local/bin"
export PATH
unset -f _atomic_path

[ "$(uname)" = Linux ] && [ -z "${LANG:-}" ] && export LANG=C.UTF-8
export COLORTERM="${COLORTERM:-truecolor}"
export EDITOR="${EDITOR:-hx}" VISUAL="${VISUAL:-hx}"

# Headless Claude Code login, if install.sh was given CLAUDE_CODE_OAUTH_TOKEN
# shellcheck disable=SC1091
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/atomic-dev/secrets.env" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/atomic-dev/secrets.env"

# Optional: interactive SSH logins land in the IDE (install.sh --auto-attach DIR)
_atomic_env="${XDG_CONFIG_HOME:-$HOME/.config}/atomic-dev/env"
# shellcheck disable=SC1090
[ -f "$_atomic_env" ] && . "$_atomic_env"
unset _atomic_env
case $- in
  *i*) if [ -n "${ATOMIC_AUTO_ATTACH:-}" ] && [ -n "${SSH_TTY:-}" ] && [ -z "${ZELLIJ:-}" ]; then
         ide "$ATOMIC_AUTO_ATTACH"
       fi ;;
esac

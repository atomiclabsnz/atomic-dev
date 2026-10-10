# Shared helpers, sourced by install.sh (and through it, steps/*.sh)

BIN="$HOME/.local/bin"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP=$(date +%Y%m%d-%H%M%S)

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Move an existing file aside before we replace it
backup() { if [ -e "$1" ] || [ -L "$1" ]; then mv "$1" "$1.bak-$STAMP" && say "Backed up $1"; fi; }

# link SRC DEST: symlink DEST -> SRC, backing up whatever was there. No-op if already linked.
link() {
  [ "$(readlink "$2" 2>/dev/null)" = "$1" ] && return 0
  mkdir -p "$(dirname "$2")"
  backup "$2"
  ln -s "$1" "$2"
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif have sudo; then sudo "$@"
  else die "Need root for: $* (install sudo or run as root)"; fi
}

# Sets OS to macos | debian | arch
detect_os() {
  if [ "$(uname)" = Darwin ]; then OS=macos; return; fi
  [ -r /etc/os-release ] || die "Unsupported OS: no /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*) OS=debian ;;
    *" arch "*) OS=arch ;;
    *) die "Unsupported distro: ${PRETTY_NAME:-$ID}. Supported: Ubuntu/Debian, Arch, macOS." ;;
  esac
}

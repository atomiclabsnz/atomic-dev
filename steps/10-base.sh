# Base OS packages only. Everything else comes from mise (30-mise.sh) so versions match across machines.
if [ "$SKIP_BASE" = 0 ] && [ -z "${BASE_DONE:-}" ]; then
  case "$OS" in
    debian)
      pkgs=(git curl ca-certificates unzip xz-utils file less procps openssh-client bsdutils)
      [ "$IN_CONTAINER" = 1 ] || pkgs+=(build-essential sudo locales)
      missing=()
      for p in "${pkgs[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
      if [ ${#missing[@]} -gt 0 ]; then
        say "Installing base packages: ${missing[*]}"
        as_root apt-get update -qq
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${missing[@]}"
      fi
      ;;
    arch)
      pkgs=(git curl unzip file less procps-ng openssh which util-linux)
      [ "$IN_CONTAINER" = 1 ] || pkgs+=(base-devel sudo)
      missing=()
      for p in "${pkgs[@]}"; do pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p"); done
      if [ ${#missing[@]} -gt 0 ]; then
        say "Installing base packages: ${missing[*]}"
        as_root pacman -Sy --needed --noconfirm "${missing[@]}"
      fi
      ;;
    macos)
      xcode-select -p >/dev/null 2>&1 || die "Install the Xcode command line tools first: xcode-select --install"
      # Fonts only matter where the terminal runs, so only on the Mac
      if have brew && ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
        say "Installing JetBrainsMono Nerd Font"
        brew install --cask font-jetbrains-mono-nerd-font || warn "Font install failed; icons may not render"
      fi
      ;;
  esac
  BASE_DONE=1
fi

# Docker, for projects with a dev container (bin/ide-devcontainer). On macOS use OrbStack or
# Docker Desktop instead; the devcontainer CLI itself comes from mise.
if [ "$WITH_DOCKER" = 1 ] && [ "$OS" != macos ]; then
  if ! have docker; then
    say "Installing Docker"
    case "$OS" in
      debian) as_root apt-get update -qq
              as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends docker.io ;;
      arch) as_root pacman -S --needed --noconfirm docker ;;
    esac
  fi
  # Start it at boot, where systemd runs (not in plain containers)
  if [ -d /run/systemd/system ] && ! systemctl is-enabled --quiet docker 2>/dev/null; then
    as_root systemctl enable --now docker
  fi
  if ! id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    as_root usermod -aG docker "$(id -un)"
    say "Added $(id -un) to the docker group (takes effect at your next login)"
  fi
elif [ "$WITH_DOCKER" = 1 ] && ! have docker; then
  warn "No Docker found. For projects with a dev container, install OrbStack or Docker Desktop."
fi

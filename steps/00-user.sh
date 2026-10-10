# --user NAME (run as root on a fresh server): install base packages, create a sudo user
# with root's SSH keys and a copy of this repo, then continue the install as that user.
if [ -n "$NEW_USER" ]; then
  [ "$(id -u)" -eq 0 ] || die "--user must be run as root"
  [ "$OS" != macos ] || die "--user is for Linux servers"

  # shellcheck source=steps/10-base.sh
  . "$ATOMIC_HOME/steps/10-base.sh"

  if ! id "$NEW_USER" >/dev/null 2>&1; then
    say "Creating user $NEW_USER"
    useradd --create-home --shell /bin/bash "$NEW_USER"
  fi
  if [ "$OS" = arch ]; then usermod -aG wheel "$NEW_USER"; else usermod -aG sudo "$NEW_USER"; fi
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-atomic-dev-$NEW_USER"
  chmod 440 "/etc/sudoers.d/90-atomic-dev-$NEW_USER"

  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  if [ -f /root/.ssh/authorized_keys ] && [ ! -f "$user_home/.ssh/authorized_keys" ]; then
    say "Copying root's SSH authorized_keys to $NEW_USER"
    install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$user_home/.ssh"
    install -m 600 -o "$NEW_USER" -g "$NEW_USER" /root/.ssh/authorized_keys "$user_home/.ssh/authorized_keys"
  fi

  mkdir -p "$user_home/.atomic-dev"
  cp -a "$ATOMIC_HOME/." "$user_home/.atomic-dev/"
  chown -R "$NEW_USER:" "$user_home/.atomic-dev"

  user_args=(--skip-base)
  [ "$WITH_CLAUDE" = 1 ] || user_args+=(--no-claude)
  [ "$WITH_RUST" = 1 ] || user_args+=(--no-rust)
  [ -z "$AUTO_ATTACH" ] || user_args+=(--auto-attach "$AUTO_ATTACH")
  say "Continuing as $NEW_USER"
  exec sudo -u "$NEW_USER" -H --preserve-env=GIT_NAME,GIT_EMAIL,ATOMIC_REPOS,GITHUB_TOKEN \
    bash "$user_home/.atomic-dev/install.sh" "${user_args[@]}"
fi

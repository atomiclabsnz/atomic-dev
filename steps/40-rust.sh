# Rust via rustup (rather than mise) so rust-analyzer matches the toolchain
if [ "$WITH_RUST" = 1 ]; then
  if ! have rustup && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
    say "Installing Rust (rustup)"
    curl --proto '=https' -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
  fi
  RUSTUP=$(command -v rustup || echo "$HOME/.cargo/bin/rustup")
  "$RUSTUP" show active-toolchain >/dev/null 2>&1 || "$RUSTUP" default stable
  say "Adding Rust components"
  "$RUSTUP" component add rust-analyzer rust-src clippy rustfmt
fi

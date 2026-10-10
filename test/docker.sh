#!/usr/bin/env bash
# Install into fresh containers the way a new server would be set up (as root, with --user dev),
# re-run to check idempotency, then check the tools and run the IDE smoke test as `dev`.
# Usage: test/docker.sh [image ...]    (default: ubuntu:24.04 debian:12 archlinux:latest)
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd -P)
[ $# -gt 0 ] || set -- ubuntu:24.04 debian:12 archlinux:latest

failed=()
for image in "$@"; do
  printf '\n\033[1m######## %s ########\033[0m\n' "$image"
  platform=()
  case "$image" in archlinux*) platform=(--platform linux/amd64) ;; esac   # no arm64 Arch image
  docker run --rm ${platform[@]+"${platform[@]}"} -v "$REPO":/src:ro \
    -e GIT_NAME="Smoke Test" -e GIT_EMAIL="smoke@example.com" ${GITHUB_TOKEN:+-e GITHUB_TOKEN} \
    "$image" bash /src/test/in-container.sh || failed+=("$image")
done

if [ ${#failed[@]} -gt 0 ]; then echo "FAILED: ${failed[*]}"; exit 1; fi
echo "All images passed: $*"

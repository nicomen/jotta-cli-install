#!/usr/bin/env bash
#
# Host side. Runs scripts/test-install.sh inside one distro container.
#
# Native and emulated architectures take exactly the same path — the only
# difference is `docker run --platform`, so an armhf leg is the same code as an
# amd64 leg. Set NEEDS_QEMU=1 to install binfmt handlers first.
#
#   IMAGE=debian:12 PLATFORM=linux/amd64 scripts/run-target.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

IMAGE="${IMAGE:?set IMAGE, e.g. debian:12}"
PLATFORM="${PLATFORM:-linux/amd64}"
NEEDS_QEMU="${NEEDS_QEMU:-0}"
OUTDIR="${OUTDIR:-$PWD/results}"
TIMEOUT="${TIMEOUT:-1800}"

mkdir -p "$OUTDIR"

if [ "$NEEDS_QEMU" = "1" ]; then
  info "Installing binfmt handlers for ${PLATFORM}"
  docker run --rm --privileged tonistiigi/binfmt:latest --install all >/dev/null
fi

info "Running ${IMAGE} (${PLATFORM})"

# Every JOTTA_* setting is forwarded so a single environment override on the
# workflow reaches the container without editing anything here.
# printenv lists only exported variables, so the container gets the caller's
# overrides and falls back to the defaults in common.sh for everything else.
env_args=()
while IFS='=' read -r var _; do
  env_args+=(-e "$var")
done < <(printenv | grep '^JOTTA_' || true)

exec timeout --signal=TERM --kill-after=60 "$TIMEOUT" \
  docker run --rm \
    --platform "$PLATFORM" \
    -v "$HERE:/opt/jotta-tests:ro" \
    -v "$OUTDIR:/out" \
    "${env_args[@]}" \
    -e JOTTA_RESULTS=/out/results.tsv \
    "$IMAGE" \
    bash /opt/jotta-tests/test-install.sh

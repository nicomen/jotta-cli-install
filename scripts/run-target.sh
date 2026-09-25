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
# CONTAINER_RUNTIME selects the engine (default docker, as on GitHub runners);
# set it to podman to drive the same leg rootless on a workstation.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

RUNTIME="${CONTAINER_RUNTIME:-docker}"
command -v "$RUNTIME" >/dev/null 2>&1 || die "no container runtime: $RUNTIME not found"

IMAGE="${IMAGE:?set IMAGE, e.g. debian:12}"
PLATFORM="${PLATFORM:-linux/amd64}"
NEEDS_QEMU="${NEEDS_QEMU:-0}"
OUTDIR="${OUTDIR:-$PWD/results}"
TIMEOUT="${TIMEOUT:-1800}"

mkdir -p "$OUTDIR"

if [ "$NEEDS_QEMU" = "1" ]; then
  info "Installing binfmt handlers for ${PLATFORM}"
  "$RUNTIME" run --rm --privileged tonistiigi/binfmt:latest --install all >/dev/null
fi

# podman has no default registry for short names; docker assumes docker.io.
if [ "$RUNTIME" = podman ]; then
  case "$IMAGE" in
    localhost/*) ;;                  # explicit localhost registry
    *.*/*|*:*/*) ;;                  # first segment has a dot/port -> real
                                      # registry host (quay.io/..., registry.
                                      # access.redhat.com/..., ...). The
                                      # previous pattern (*/*.*/*) required
                                      # the dot to fall *between* two
                                      # slashes, which a bare "host.tld/..."
                                      # reference never has -- found when
                                      # quay.io/almalinuxorg/almalinux:9
                                      # wrongly got "docker.io/" prepended.
    *)                  IMAGE="docker.io/${IMAGE}" ;;
  esac
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
  "$RUNTIME" run --rm \
    --platform "$PLATFORM" \
    -v "$HERE:/opt/jotta-tests:ro" \
    -v "$OUTDIR:/out" \
    "${env_args[@]}" \
    -e JOTTA_RESULTS=/out/results.tsv \
    "$IMAGE" \
    bash /opt/jotta-tests/test-install.sh

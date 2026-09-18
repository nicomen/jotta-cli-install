#!/usr/bin/env bash
#
# Run the whole matrix locally, the same way CI does, and render the grid.
#
#   scripts/run-all.sh                 # broad tier, whatever this host can run
#   scripts/run-all.sh core            # the four quick legs
#   scripts/run-all.sh all             # including the emulated ones
#   JOBS=3 scripts/run-all.sh          # three legs at a time
#
# CONTAINER_RUNTIME picks the engine (podman or docker; default: whichever is
# installed, preferring docker to match the GitHub runners).
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

TIER="${1:-broad}"
JOBS="${JOBS:-2}"
RESULTS="${RESULTS:-$ROOT/results}"
MATRIX="${MATRIX:-$ROOT/matrix.json}"

if [ -z "${CONTAINER_RUNTIME:-}" ]; then
  for r in docker podman; do
    command -v "$r" >/dev/null 2>&1 && { CONTAINER_RUNTIME="$r"; break; }
  done
fi
: "${CONTAINER_RUNTIME:?no container runtime found — install docker or podman}"
export CONTAINER_RUNTIME

command -v jq >/dev/null 2>&1 || die "jq is required"

case "$TIER" in
  core)  filter='.tier == "core"' ;;
  broad) filter='.tier == "core" or .tier == "broad"' ;;
  all)   filter='true' ;;
  *)     die "unknown tier: $TIER (want core, broad or all)" ;;
esac

# Can this host run that platform without binfmt handlers?
native_platform() { # native_platform <platform>
  local want="$1" host
  host="$(uname -m)"
  case "$host/$want" in
    x86_64/linux/amd64)  return 0 ;;
    # 32-bit x86 runs natively on an x86-64 kernel.
    x86_64/linux/386)    return 0 ;;
    aarch64/linux/arm64) return 0 ;;
    aarch64/linux/arm/v7) return 0 ;;
  esac
  return 1
}

binfmt_ready() { # binfmt_ready <platform>
  case "$1" in
    linux/arm64)  [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] ;;
    linux/arm/v7) [ -e /proc/sys/fs/binfmt_misc/qemu-arm ] ;;
    linux/386)    return 0 ;;
    *)            return 1 ;;
  esac
}

mkdir -p "$RESULTS"

selected=0
skipped=0
declare -a queue=()

while IFS=$'\t' read -r id image platform name; do
  if ! native_platform "$platform" && ! binfmt_ready "$platform"; then
    warn "skipping ${name} — ${platform} needs binfmt handlers this host does not have"
    skipped=$((skipped + 1))
    continue
  fi
  queue+=("$id"$'\t'"$image"$'\t'"$platform"$'\t'"$name")
  selected=$((selected + 1))
done < <(jq -r "[.targets[] | select($filter)][] | [.id, .image, .platform, .name] | @tsv" "$MATRIX")

info "${selected} legs to run (${skipped} skipped), ${JOBS} at a time, via ${CONTAINER_RUNTIME}"

running=0
for entry in "${queue[@]}"; do
  IFS=$'\t' read -r id image platform name <<< "$entry"
  (
    if IMAGE="$image" PLATFORM="$platform" OUTDIR="$RESULTS/$id" \
       "$HERE/run-target.sh" > "$RESULTS/$id.log" 2>&1; then
      printf '  ok   %s\n' "$name"
    else
      printf '  FAIL %s  (see %s)\n' "$name" "$RESULTS/$id.log"
    fi
  ) &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then
    wait -n 2>/dev/null || wait
    running=$((running - 1))
  fi
done
wait

info "Results"
"$HERE/report.sh" --grid "$RESULTS" "$MATRIX"
printf '\n'
"$HERE/report.sh" --failures "$RESULTS"

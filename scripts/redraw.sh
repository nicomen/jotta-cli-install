#!/usr/bin/env bash
#
# Re-render the grid from the last real CI run's data, no containers, no
# images, no new install legs. For iterating on scripts/report.sh's
# formatting (the grid layout, the legend, grouping, ...) without waiting
# ~15-20 minutes for the full matrix to re-run: pull down what the last
# run already found, and run today's rendering logic against it.
#
#   scripts/redraw.sh                # print the grid to stdout
#   scripts/redraw.sh --write        # splice it into README.md, like CI does
#   scripts/redraw.sh --run 35477... # use a specific run instead of the latest
#
# Needs `gh`, authenticated against this repo.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

WRITE=0
RUN_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1; shift ;;
    --run)   RUN_ID="$2"; shift 2 ;;
    *)       die "unknown argument: $1" ;;
  esac
done

command -v gh >/dev/null 2>&1 || die "gh CLI is required"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
: "${REPO:?could not determine the repo — run this from inside a checkout, or 'gh auth login' first}"

RESULTS="$ROOT/results-redraw"
rm -rf "$RESULTS"
mkdir -p "$RESULTS"

if [ -z "$RUN_ID" ]; then
  info "Finding the most recent completed run of install-matrix.yml"
  RUN_ID="$(gh run list -R "$REPO" --workflow install-matrix.yml \
    --json databaseId,status --jq '[.[] | select(.status == "completed")][0].databaseId')"
  [ -n "$RUN_ID" ] || die "no completed run found"
fi
info "Using run $RUN_ID (${GITHUB_SERVER_URL:-https://github.com}/$REPO/actions/runs/$RUN_ID)"

info "Downloading result artifacts (not logs, not images -- just the small results.tsv files)"
artifacts="$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" --paginate \
  --jq '.artifacts[] | select(.name | startswith("results-")) | [.id, .name] | @tsv')"
[ -n "$artifacts" ] || die "no results-* artifacts on run $RUN_ID (maybe it's still running, or too old and expired)"

count=0
while IFS=$'\t' read -r id name; do
  zip="$RESULTS/${name}.zip"
  # The artifact download redirects to a signed blob-storage URL; that hop
  # occasionally fails transiently (seen: a TLS error from an intercepting
  # proxy on one attempt, gone on retry), so retry a few times before
  # giving up on this one artifact.
  ok=0
  for attempt in 1 2 3; do
    if gh api "repos/$REPO/actions/artifacts/$id/zip" > "$zip" 2>/dev/null; then
      ok=1
      break
    fi
    warn "download of ${name} failed (attempt ${attempt}/3), retrying"
    sleep 2
  done
  if [ "$ok" -ne 1 ]; then
    warn "giving up on ${name} after 3 attempts -- it will show as no-result"
    rm -f "$zip"
    continue
  fi
  unzip -oq "$zip" -d "$RESULTS"
  rm -f "$zip"
  count=$((count + 1))
done <<< "$artifacts"
info "Fetched ${count} artifacts"

if [ "$WRITE" -eq 1 ]; then
  GITHUB_REPOSITORY="$REPO" "$HERE/update-readme.sh" "$RESULTS" "$ROOT/README.md"
  info "README.md updated from run $RUN_ID's data. Diff it, and commit/push yourself when happy."
else
  "$HERE/report.sh" --grid "$RESULTS" "$ROOT/matrix.json"
  printf '\n'
  "$HERE/report.sh" --failures "$RESULTS"
fi

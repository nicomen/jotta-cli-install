#!/usr/bin/env bash
#
# Splices the current status grid into README.md, between the markers
#
#   <!-- STATUS:BEGIN -->  ...  <!-- STATUS:END -->
#
# Everything between them is generated; everything else in the README is left
# untouched. Run by the `summary` job on main and on the nightly cron, so the
# repository front page always shows the last known state.
#
#   scripts/update-readme.sh [results-dir] [readme]
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

RESULTS="${1:-results}"
README="${2:-README.md}"
BEGIN='<!-- STATUS:BEGIN -->'
END='<!-- STATUS:END -->'

grep -qF "$BEGIN" "$README" || die "$README has no ${BEGIN} marker"
grep -qF "$END"   "$README" || die "$README has no ${END} marker"

block="$(mktemp)"
trap 'rm -f "$block"' EXIT

repo="${GITHUB_REPOSITORY:-jotta/jotta-cli-issues}"
server="${GITHUB_SERVER_URL:-https://github.com}"
workflow='install-matrix.yml'

{
  printf '\n[![install matrix](%s/%s/actions/workflows/%s/badge.svg)](%s/%s/actions/workflows/%s)\n\n' \
    "$server" "$repo" "$workflow" "$server" "$repo" "$workflow"

  # scripts/report.sh writes to $GITHUB_STEP_SUMMARY when it is set; unset it
  # here so the same renderer writes to stdout instead.
  GITHUB_STEP_SUMMARY='' "$HERE/report.sh" --grid "$RESULTS" "$(dirname "$HERE")/matrix.json" || true

  printf '\n'
  if ! GITHUB_STEP_SUMMARY='' "$HERE/report.sh" --failures "$RESULTS" > "${block}.fail"; then
    printf '**Failing checks**\n\n'
    cat "${block}.fail"
  else
    cat "${block}.fail"
  fi
  rm -f "${block}.fail"

  version="$(curl -fsSL --retry 3 "${JOTTA_HOST}/archives/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
  printf '<sub>%s · published version `%s` · signing key `%s`' \
    "$(date -u '+%Y-%m-%d %H:%M UTC')" "${version:-unknown}" "$JOTTA_EXPECTED_FPR"
  if [ -n "${GITHUB_RUN_ID:-}" ]; then
    printf ' · [run](%s/%s/actions/runs/%s)' "$server" "$repo" "$GITHUB_RUN_ID"
  fi
  printf '</sub>\n\n'
} > "$block"

{
  sed -n "1,/$(printf '%s' "$BEGIN" | sed 's/[][\.*^$/]/\\&/g')/p" "$README"
  cat "$block"
  sed -n "/$(printf '%s' "$END" | sed 's/[][\.*^$/]/\\&/g')/,\$p" "$README"
} > "${README}.new"

mv "${README}.new" "$README"
info "Updated ${README}"

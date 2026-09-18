#!/usr/bin/env bash
#
# Renders one or more results.tsv files as a Markdown report.
# Writes to $GITHUB_STEP_SUMMARY when set, otherwise to stdout.
#
#   scripts/report.sh "Debian 12 / amd64" results/results.tsv
#   scripts/report.sh --all results/            # every results.tsv underneath
#
set -euo pipefail

out() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  else
    printf '%s\n' "$*"
  fi
}

# Markdown table cells cannot contain a raw pipe or newline.
cell() { printf '%s' "$1" | tr '\n|' '  ' | sed 's/`/'"'"'/g' | cut -c1-200; }

render_one() {
  local title="$1" file="$2"
  local failed=0 passed=0

  if [ ! -s "$file" ]; then
    out "### ❓ ${title}"
    out ""
    out "No results were produced — the job died before recording anything."
    out ""
    return 1
  fi

  while IFS=$'\t' read -r name status _; do
    case "$status" in pass) passed=$((passed+1)) ;; fail) failed=$((failed+1)) ;; esac
  done < "$file"

  local icon="✅" open_attr=""
  if [ "$failed" -gt 0 ]; then
    icon="❌"
    open_attr=" open"   # expand failing legs by default
  fi
  out "<details${open_attr}>"
  out "<summary>${icon} <b>${title}</b> — ${passed} passed, ${failed} failed</summary>"
  out ""
  out "| | Check | Detail |"
  out "|---|---|---|"
  while IFS=$'\t' read -r name status detail; do
    case "$status" in
      pass) out "| ✅ | $(cell "$name") | |" ;;
      fail) out "| ❌ | $(cell "$name") | \`$(cell "$detail")\` |" ;;
      info) out "| ℹ️ | $(cell "$name") | $(cell "$detail") |" ;;
    esac
  done < "$file"
  out ""
  out "</details>"
  out ""

  [ "$failed" -eq 0 ]
}

main() {
  local rc=0
  if [ "${1:-}" = "--all" ]; then
    local dir="${2:-results}" f title
    while read -r f; do
      # results/<target-id>/results.tsv  ->  title from the directory name
      title="$(basename "$(dirname "$f")")"
      render_one "$title" "$f" || rc=1
    done < <(find "$dir" -name 'results.tsv' | sort)
  else
    render_one "${1:?title}" "${2:?results file}" || rc=1
  fi
  return $rc
}

main "$@"

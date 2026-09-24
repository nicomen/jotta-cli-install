#!/usr/bin/env bash
#
# Renders one or more results.tsv files as a Markdown report.
# Writes to $GITHUB_STEP_SUMMARY when set, otherwise to stdout.
#
#   scripts/report.sh "Debian 12 / amd64" results/results.tsv
#   scripts/report.sh --all results/       # every results.tsv underneath
#   scripts/report.sh --grid results/      # distro x arch status grid
#   scripts/report.sh --failures results/  # failing checks, grouped
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

# ---------------------------------------------------------------------------
# Status grid: distro down the side, architecture across the top.
# Joins results/<target-id>/results.tsv against the target list in matrix.json,
# so legs that were not part of the selected tier are shown as not-run rather
# than silently disappearing.
# ---------------------------------------------------------------------------

# leg_status <results-dir> <target-id>  ->  pass | fail | missing
leg_status() {
  local file="$1/$2/results.tsv"
  [ -s "$file" ] || { printf 'missing\n'; return; }
  local fails passes
  fails="$(cut -f2 "$file" | grep -cx fail)"
  passes="$(cut -f2 "$file" | grep -cx pass)"
  if [ "$fails" -gt 0 ]; then
    printf 'fail\n'
  elif [ "$passes" -gt 0 ]; then
    printf 'pass\n'
  else
    # Zero of both: the leg died before any check() ran (e.g. in bootstrap) and
    # only left "info" rows behind, or crashed hard enough to leave nothing at
    # all. Either way this is not a pass.
    printf 'fail\n'
  fi
}

# Wraps the emoji in a <span title="..."> so hovering over a cell explains it
# without needing the legend below — GitHub renders inline HTML in table
# cells (same as the distro <img> icons already do).
status_icon() { # status_icon <pass|fail|missing|none_col>
  local status="$1" glyph text
  case "$status" in
    pass)     glyph='✅'; text="passed" ;;
    fail)     glyph='❌'; text="failed" ;;
    missing)  glyph='⏳'; text="in the matrix, but no result yet (run in progress, or its job didn't finish)" ;;
    none_col) glyph='·';  text="not published for this architecture" ;;
    *)        glyph='·';  text="not published for this architecture" ;;
  esac
  printf '<span title="%s">%s</span>' "$text" "$glyph"
}

# Official brand mark for a distro name, via Simple Icons' CDN (their default
# brand colour, no API key, no local asset to keep in sync). Matched on
# substrings of the "distro" field rather than the id, so "RHEL 8 (UBI)" and
# "RHEL 9 (UBI)" share one lookup instead of needing a per-version entry.
distro_icon_slug() {
  case "$1" in
    *Debian*)     printf 'debian'     ;;
    *Ubuntu*)     printf 'ubuntu'     ;;
    *Fedora*)     printf 'fedora'     ;;
    *RHEL*)       printf 'redhat'     ;;
    *Rocky*)      printf 'rockylinux' ;;
    *AlmaLinux*)  printf 'almalinux'  ;;
    *CentOS*)     printf 'centos'     ;;
    *openSUSE*)   printf 'opensuse'   ;;
    *SLES*)       printf 'suse'       ;;
    *Arch*)       printf 'archlinux'  ;;
    *)            printf ''           ;;
  esac
}

distro_label() { # distro_label <distro name>
  local slug icon=""
  slug="$(distro_icon_slug "$1")"
  if [ -n "$slug" ]; then
    icon="<img src=\"https://cdn.simpleicons.org/${slug}\" width=\"16\" height=\"16\" valign=\"middle\" alt=\"\"> "
  fi
  printf '%s%s' "$icon" "$1"
}

UNSTABLE_DISTRO_SUFFIX=" — jotta unstable channel"

# Renders one arch's two columns (stable, unstable) for one distro row.
grid_arch_cells() { # grid_arch_cells <results-dir> <matrix> <distro> <arch>
  local dir="$1" matrix="$2" distro="$3" arch="$4" channel_distro id st out_cells=""
  for channel_distro in "$distro" "${distro}${UNSTABLE_DISTRO_SUFFIX}"; do
    id="$(jq -r --arg d "$channel_distro" --arg a "$arch" \
      'first(.targets[] | select(.distro == $d and .arch == $a) | .id) // ""' "$matrix")"
    if [ -z "$id" ]; then
      out_cells+=" $(status_icon none_col) |"
      continue
    fi
    st="$(leg_status "$dir" "$id")"
    GRID_ANY=1
    [ "$st" = fail ] && GRID_WORST=fail
    out_cells+=" $(status_icon "$st") |"
  done
  printf '%s' "$out_cells"
}

render_grid() {
  local dir="${1:-results}" matrix="${2:-matrix.json}"

  if ! command -v jq >/dev/null 2>&1; then
    out "_No grid: \`jq\` is not installed._"
    return 0
  fi
  [ -f "$matrix" ] || { out "_No grid: ${matrix} not found._"; return 0; }

  local ordered='reduce .[] as $v ([]; if index([$v]) then . else . + [$v] end)'
  local arches
  mapfile -t arches < <(jq -r "[.targets[].arch] | ${ordered} | .[]" "$matrix")

  # Rows: one per base OS (the unstable-channel clones don't get their own
  # row -- their results feed the "unstable" column instead), grouped by
  # family (each group ordered by its own earliest release), each group
  # internally still oldest-release-first.
  local rows
  rows="$(jq -c --arg sfx "$UNSTABLE_DISTRO_SUFFIX" '
    [.targets[] | select(.distro | endswith($sfx) | not)] | unique_by(.distro) as $bases |
    ($bases | group_by(.group) |
     map({group: .[0].group, min: (map(.released) | map(if . == "rolling" then "9999-99-99" else . end) | min)}) |
     sort_by(.min) | map(.group)) as $group_order |
    $bases | sort_by(
      (.group as $g | $group_order | index($g)),
      (if .released == "rolling" then "9999-99-99" else .released end)
    )
  ' "$matrix")"

  local header="| Distro | Released | EOL |" sep="|---|:-:|:-:|"
  local a
  for a in "${arches[@]}"; do
    header+=" ${a} (stable) | ${a} (unstable) |"
    sep+=":-:|:-:|"
  done
  out "$header"
  out "$sep"

  local today
  today="$(date -u +%Y-%m-%d)"
  GRID_ANY=0
  GRID_WORST=pass

  local prev_group="" cur_group distro released eol eol_cell row
  local n
  n="$(jq 'length' <<<"$rows")"
  local i
  for ((i = 0; i < n; i++)); do
    local entry
    entry="$(jq -c ".[$i]" <<<"$rows")"
    distro="$(jq -r '.distro' <<<"$entry")"
    cur_group="$(jq -r '.group // "Other"' <<<"$entry")"
    released="$(jq -r '.released' <<<"$entry")"
    eol="$(jq -r '.eol' <<<"$entry")"

    if [ "$cur_group" != "$prev_group" ]; then
      local blank=""
      for a in "${arches[@]}"; do blank+="  |  |"; done
      out "| **${cur_group}** |  |  |${blank}"
      prev_group="$cur_group"
    fi

    if [ "$eol" = rolling ]; then
      eol_cell="rolling"
    elif [[ "$eol" < "$today" ]]; then
      eol_cell="⚠️ ${eol}"   # already past EOL as of today
    else
      eol_cell="$eol"
    fi

    row="| $(distro_label "$distro") | <span style=\"white-space:nowrap\">${released}</span> | <span style=\"white-space:nowrap\">${eol_cell}</span> |"
    for a in "${arches[@]}"; do
      row+="$(grid_arch_cells "$dir" "$matrix" "$distro" "$a")"
    done
    out "$row"
  done
  out ""
  out "Each cell is one leg -- jotta's stable and unstable package channels"
  out "side by side (see \"What it checks\" for what unstable means)."
  out "✅ passed · ❌ failed · ⏳ no result yet (run in progress) · · not published"
  out "for that architecture/channel."
  out "⚠️ next to an EOL date means it's already past that date as of today. Rows are"
  out "grouped by family, oldest-release-first within each group; GitHub renders this"
  out "as a static table (no JS allowed in READMEs), so there's no interactive re-sort."

  [ "$GRID_ANY" -eq 1 ] || return 0
  [ "$GRID_WORST" = pass ]
}

# Per-check view: which individual checks failed, and where. Far more useful
# than the grid when one thing breaks across several legs at once.
render_failures() {
  local dir="${1:-results}"
  local tmp
  tmp="$(mktemp)"

  while read -r f; do
    local leg
    leg="$(basename "$(dirname "$f")")"
    awk -F'\t' -v leg="$leg" '$2 == "fail" { print $1 "\t" leg }' "$f" >> "$tmp"
  done < <(find "$dir" -name 'results.tsv' | sort)

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    out "All checks passed on every leg that ran."
    out ""
    return 0
  fi

  out "| Failing check | Legs |"
  out "|---|---|"
  local check legs
  while read -r check; do
    legs="$(awk -F'\t' -v c="$check" '$1 == c { printf "%s%s", sep, $2; sep=", " } END { print "" }' "$tmp")"
    out "| $(cell "$check") | $(cell "$legs") |"
  done < <(cut -f1 "$tmp" | sort -u)
  out ""
  rm -f "$tmp"
  return 1
}

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

  # Zero pass and zero fail means the leg died before any check() ran (only
  # "info" rows were recorded) — that is a crash, not a clean pass.
  if [ "$failed" -eq 0 ] && [ "$passed" -eq 0 ]; then
    out "<details open>"
    out "<summary>❓ <b>${title}</b> — no checks ran</summary>"
    out ""
    out "The job died before recording any pass or fail — see its log."
    out ""
    out "</details>"
    out ""
    return 1
  fi

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
  if [ "${1:-}" = "--grid" ]; then
    render_grid "${2:-results}" "${3:-matrix.json}" || rc=1
    return $rc
  fi
  if [ "${1:-}" = "--failures" ]; then
    render_failures "${2:-results}" || rc=1
    return $rc
  fi
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

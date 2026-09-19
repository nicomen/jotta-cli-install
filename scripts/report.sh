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

status_icon() {
  case "$1" in
    pass)    printf '%s' '✅' ;;
    fail)    printf '%s' '❌' ;;
    missing) printf '%s' '⏳' ;;   # in the matrix, no result this run
    none)     printf '%s' '—' ;;   # ran, but never reached this phase
    none_col) printf '%s' '·' ;;   # not a published target (whole column)
    *)        printf '%s' '·' ;;
  esac
}

# Which numbered step (from info()'s "PHASE: N. ..." markers, see common.sh)
# a check happened under, bucketed into "install" (steps 1-3, plus the
# counter-check — signature enforcement is an install-time property) or
# "run" (step 4, the daemon smoke test). Prints: pass | fail | none
leg_phase_status() { # leg_phase_status <results-dir> <target-id> <install|run>
  local file="$1/$2/results.tsv" want="$3"
  [ -s "$file" ] || { printf 'none\n'; return; }

  awk -F'\t' -v want="$want" '
    # A failure before any phase marker (bootstrap itself dying, e.g. Debian
    # 11s apt-get install failing) is still an install-time failure, not a
    # blank -- default the bucket accordingly rather than leaving it unset.
    BEGIN                          { bucket = "install" }
    /^PHASE: 4\./                 { bucket = "run"; next }
    /^PHASE: [1-3]\./             { bucket = "install"; next }
    /^PHASE: Counter-check/       { bucket = "install"; next }
    $2 == "pass" || $2 == "fail"  {
      if (bucket == want) { seen = 1; if ($2 == "fail") failed = 1 }
    }
    END {
      if (!seen)      print "none"
      else if (failed) print "fail"
      else             print "pass"
    }
  ' "$file"
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

render_grid() {
  local dir="${1:-results}" matrix="${2:-matrix.json}"

  if ! command -v jq >/dev/null 2>&1; then
    out "_No grid: \`jq\` is not installed._"
    return 0
  fi
  [ -f "$matrix" ] || { out "_No grid: ${matrix} not found._"; return 0; }

  # Column and row order follow matrix.json rather than being sorted, so the
  # grid keeps the order a human put the targets in.
  local ordered='reduce .[] as $v ([]; if index([$v]) then . else . + [$v] end)'
  local arches distros
  mapfile -t arches  < <(jq -r "[.targets[].arch]   | ${ordered} | .[]" "$matrix")
  mapfile -t distros < <(jq -r "[.targets[].distro] | ${ordered} | .[]" "$matrix")

  local header="| Distro |" sep="|---|"
  local a d id st row worst=pass any=0
  for a in "${arches[@]}"; do
    header+=" ${a} |"
    sep+=":-:|"
  done
  out "$header"
  out "$sep"

  for d in "${distros[@]}"; do
    row="| $(distro_label "$d") |"
    for a in "${arches[@]}"; do
      id="$(jq -r --arg d "$d" --arg a "$a" \
        'first(.targets[] | select(.distro == $d and .arch == $a) | .id) // ""' "$matrix")"
      if [ -z "$id" ]; then
        row+=" $(status_icon none_col) |"
      else
        st="$(leg_status "$dir" "$id")"
        any=1
        if [ "$st" = fail ]; then worst=fail; fi
        if [ "$st" = missing ]; then
          row+=" $(status_icon missing) |"
        else
          local i_st r_st
          i_st="$(leg_phase_status "$dir" "$id" install)"
          r_st="$(leg_phase_status "$dir" "$id" run)"
          row+=" $(status_icon "$i_st")/$(status_icon "$r_st") |"
        fi
      fi
    done
    out "$row"
  done
  out ""
  out "Each cell is install/run. ✅ passed · ❌ failed · — not reached (an earlier phase failed) ·"
  out "⏳ not run in this tier · · not published for that architecture"

  [ "$any" -eq 1 ] || return 0
  [ "$worst" = pass ]
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

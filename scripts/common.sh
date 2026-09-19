#!/usr/bin/env bash
# Shared helpers for the jotta-cli install/signing test matrix.
# Sourced by every script in this repo — host side and in-container.
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Repository facts. Override any of these via the environment to test a
# staging repo, a different suite, or a rotated key.
# ---------------------------------------------------------------------------

# Current documented host. The old host is kept as a mirror.
JOTTA_HOST="${JOTTA_HOST:-https://repo.jotta.cloud}"
JOTTA_HOST_LEGACY="${JOTTA_HOST_LEGACY:-https://repo.jotta.us}"

# Path of the signing key as the current docs reference it.
JOTTA_KEY_PATH="${JOTTA_KEY_PATH:-/jotta.gpg}"
# Path referenced by older docs/blog posts. Still served, different key.
JOTTA_KEY_PATH_LEGACY="${JOTTA_KEY_PATH_LEGACY:-/public.gpg}"

JOTTA_DEB_SUITE="${JOTTA_DEB_SUITE:-debian}"      # "debian" (stable) or "unstable"
JOTTA_DEB_COMPONENT="${JOTTA_DEB_COMPONENT:-main}"
JOTTA_RPM_PATH="${JOTTA_RPM_PATH:-/redhat}"
JOTTA_PACKAGE="${JOTTA_PACKAGE:-jotta-cli}"

# Fingerprint that MUST sign repository metadata and packages.
# Rotated 2026-03-13 from the 2017 RSA4096 key E2CBEED2DECB21BF686AB4B37DEFBCE9947F9F0F.
JOTTA_EXPECTED_FPR="${JOTTA_EXPECTED_FPR:-DD0330E486A55840D37BDE77068CACA1BBF96E71}"
# Superseded key, still served at $JOTTA_KEY_PATH_LEGACY.
JOTTA_LEGACY_FPR="${JOTTA_LEGACY_FPR:-E2CBEED2DECB21BF686AB4B37DEFBCE9947F9F0F}"

JOTTA_KEY_URL="${JOTTA_KEY_URL:-${JOTTA_HOST}${JOTTA_KEY_PATH}}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log()  { printf '%s\n' "$*"; }
info() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '  !! %s\n' "$*" >&2; }
# A fatal error must leave a trace in the results, not just on stderr — a
# results.tsv with zero pass/fail rows (the script died before any check())
# is otherwise indistinguishable from "every check passed."
die()  { printf '  XX %s\n' "$*" >&2; record_result "fatal error" fail "$*"; exit 1; }

# Collapse multi-line command output into one short line for the TSV report.
_oneline() { tr '\n' ' ' | tr -s ' ' | cut -c1-400; }

# ---------------------------------------------------------------------------
# Result recording
#
# Every check appends one TSV row to $JOTTA_RESULTS (name, status, detail) so
# the workflow can turn a whole matrix leg into a single summary table.
# ---------------------------------------------------------------------------

JOTTA_RESULTS="${JOTTA_RESULTS:-/tmp/jotta-results.tsv}"
CHECKS_RUN=0
CHECKS_FAILED=0

record_result() {
  local name="$1" status="$2" detail="${3:-}"
  printf '%s\t%s\t%s\n' "$name" "$status" "$detail" >> "$JOTTA_RESULTS"
}

_check_impl() {
  # _check_impl <expect: pass|fail> <name> <cmd...>
  local expect="$1" name="$2"; shift 2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  CHECKS_RUN=$((CHECKS_RUN + 1))

  local good=0
  [ "$expect" = pass ] && [ "$rc" -eq 0 ] && good=1
  [ "$expect" = fail ] && [ "$rc" -ne 0 ] && good=1

  if [ "$good" -eq 1 ]; then
    log "  ok   ${name}"
    record_result "$name" pass "$(printf '%s' "$out" | _oneline)"
  else
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    if [ "$expect" = fail ]; then
      log "  FAIL ${name} (command succeeded but was expected to fail)"
    else
      log "  FAIL ${name} (exit ${rc})"
    fi
    printf '%s\n' "$out" | sed 's/^/       /'
    record_result "$name" fail "$(printf '%s' "$out" | _oneline)"
  fi
  return 0
}

# check "name" cmd...           -> the command must succeed
check() { _check_impl pass "$@"; }
# check_fails "name" cmd...     -> the command must fail (negative tests)
check_fails() { _check_impl fail "$@"; }

# note "name" "detail"          -> informational, never fails the run
note() {
  log "  --   $1: $2"
  record_result "$1" info "$2"
}

finish() {
  log ""
  log "------------------------------------------------------------"
  log "${CHECKS_RUN} checks, ${CHECKS_FAILED} failed"
  log "------------------------------------------------------------"
  [ "$CHECKS_FAILED" -eq 0 ]
}

# ---------------------------------------------------------------------------
# GPG helpers
# ---------------------------------------------------------------------------

# Primary fingerprint of the first key in a keyring/key file.
key_fingerprint() {
  gpg --show-keys --with-colons "$1" 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}'
}

# Fingerprint (or long key id) of whoever signed a signature, without needing
# the public key. Works for clearsigned files and detached .asc signatures.
signature_signer() {
  gpg --verify "$@" 2>&1 |
    sed -n 's/.*using [A-Za-z0-9]* key \([0-9A-Fa-f]\{16,\}\).*/\1/p' |
    head -n1
}

# Assert that $1 (a key file) has exactly the pinned fingerprint.
assert_key_fingerprint() {
  local keyfile="$1" want="${2:-$JOTTA_EXPECTED_FPR}" got
  got="$(key_fingerprint "$keyfile")"
  if [ "$got" != "$want" ]; then
    printf 'fingerprint mismatch: got %s want %s\n' "${got:-<none>}" "$want" >&2
    return 1
  fi
  printf '%s\n' "$got"
}

# Assert that a signature was made by the pinned key.
assert_signed_by() {
  local want="$JOTTA_EXPECTED_FPR" got
  got="$(signature_signer "$@")"
  # gpg may report the long key id (last 16 hex chars) instead of the full
  # fingerprint, so compare on the suffix.
  case "$want" in
    *"$got") printf '%s\n' "$got"; return 0 ;;
  esac
  printf 'signed by %s, expected %s\n' "${got:-<unknown>}" "$want" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

# Prints: apt | dnf | yum | zypper
detect_pkg_mgr() {
  for m in apt-get dnf yum zypper; do
    if command -v "$m" >/dev/null 2>&1; then
      printf '%s\n' "${m%-get}"
      return 0
    fi
  done
  return 1
}

os_pretty_name() {
  # shellcheck disable=SC1091
  ( . /etc/os-release 2>/dev/null && printf '%s\n' "${PRETTY_NAME:-unknown}" ) || printf 'unknown\n'
}

# Convert a binary OpenPGP key into an ASCII-armored public key block.
# rpm/dnf/zypper want armored input; the repo serves the key in binary form.
armor_key() { # armor_key <binary-key> <out.asc>
  local home
  home="$(mktemp -d)"
  chmod 700 "$home"
  gpg --homedir "$home" --batch --quiet --import "$1" &&
    gpg --homedir "$home" --batch --quiet --export --armor > "$2"
  local rc=$?
  rm -rf "$home"
  return $rc
}

# Build a throwaway keyring directory holding one key file. Prints its path.
keyring_with() { # keyring_with <key-file>
  local home
  home="$(mktemp -d)"
  chmod 700 "$home"
  gpg --homedir "$home" --batch --quiet --import "$1" >/dev/null 2>&1 || return 1
  printf '%s\n' "$home"
}

# rpm architecture name for the current machine. rpm knows best; the uname
# mapping is only a fallback for hosts without rpm.
rpm_arch() {
  if command -v rpm >/dev/null 2>&1; then
    rpm --eval '%{_arch}'
    return
  fi
  case "$(uname -m)" in
    x86_64)          printf 'x86_64\n' ;;
    aarch64|arm64)   printf 'aarch64\n' ;;
    armv7l|armv7hl)  printf 'armv7hl\n' ;;
    i386|i486|i586|i686) printf 'i386\n' ;;
    *)               uname -m ;;
  esac
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

# Install only the tools that are actually missing. Container images vary a lot
# in what they ship, and a blanket install costs more time than the checks do.
#
#   ensure_commands apt curl:curl gpg:gnupg su:util-linux
#
ensure_commands() { # ensure_commands <pkg-mgr> <cmd:package>...
  local mgr="$1"; shift
  local missing=() entry cmd pkg

  for entry in "$@"; do
    cmd="${entry%%:*}"
    pkg="${entry#*:}"
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$pkg")
  done

  # curl needs a CA bundle, and the minimal images do not always carry one.
  if [ ! -e /etc/ssl/certs/ca-certificates.crt ] &&
     [ ! -e /etc/pki/tls/certs/ca-bundle.crt ]; then
    case "$mgr" in
      apt|zypper) missing+=(ca-certificates) ;;
      *)          missing+=(ca-certificates) ;;
    esac
  fi

  if [ "${#missing[@]}" -eq 0 ]; then
    note "bootstrap: packages installed" "none needed"
    return 0
  fi

  note "bootstrap: packages installed" "${missing[*]}"

  # Captured rather than streamed: package managers are chatty, and progress
  # bars in the middle of the check list make the run hard to read. A failure
  # here is fatal, so the output is not lost, only held back.
  local out rc=0
  case "$mgr" in
    apt)
      out="$(DEBIAN_FRONTEND=noninteractive \
        apt-get install -y -qq --no-install-recommends "${missing[@]}" 2>&1)" || rc=$?
      ;;
    dnf|yum)
      out="$("$mgr" -y -q install "${missing[@]}" 2>&1)" || rc=$?
      ;;
    zypper)
      out="$(zypper --non-interactive --quiet install "${missing[@]}" 2>&1)" || rc=$?
      ;;
  esac
  [ "$rc" -eq 0 ] || die "could not install ${missing[*]}: $(printf '%s' "$out" | _oneline)"
}

# Refresh a single apt sources list instead of every configured repository.
# The base indices are already on disk from the bootstrap refresh, and
# re-fetching them for each of three updates dominates a Debian leg.
apt_update_repo() { # apt_update_repo <list-name, without .list>
  apt-get update \
    -o Dir::Etc::sourcelist="sources.list.d/$1.list" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
}

# Architecture as the packaging system sees it. `uname -m` reports the kernel,
# which says x86_64 inside a linux/386 container.
pkg_arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
  elif command -v rpm >/dev/null 2>&1; then
    rpm --eval '%{_arch}'
  else
    uname -m
  fi
}


# ---------------------------------------------------------------------------
# jotta-cli / jottad — shared by every install method (apt, dnf, zypper, AUR).
#
# The caller must, before using anything below:
#   - define installed_version(), which asks whatever packaging system it used
#   - set $WORK to a scratch directory (start_daemon_and_talk_to_it logs there)
# ---------------------------------------------------------------------------

check_binaries_and_run() {
  check "jotta-cli is on PATH"   test -x /usr/bin/jotta-cli
  check "jottad is on PATH"      test -x /usr/bin/jottad
  check "run_jottad is on PATH"  test -x /usr/bin/run_jottad

  local cli_version pkg_version
  cli_version="$(cli_version_of jotta-cli)"
  pkg_version="$(installed_version)"
  note "jotta-cli version" "${cli_version:-<none>}"
  check "CLI version matches the installed package" \
    versions_agree "$cli_version" "$pkg_version"

  start_daemon_and_talk_to_it
}

# `jotta-cli version` prints two different shapes:
#   connected  (stdout)  "jotta-cli version : 0.17.176206"  inside a table
#   no daemon  (stderr)  "jotta-cli version 0.17.176206"    before the error
# so merge the streams and accept either. Pass "jottad" for the daemon's own
# version out of the connected form.
cli_version_of() { # cli_version_of <jotta-cli|jottad> [user] [runtime-dir]
  local what="$1" user="${2:-}" rt="${3:-}" raw
  if [ -n "$user" ]; then
    raw="$(su -l "$user" -c "XDG_RUNTIME_DIR=$rt jotta-cli version" 2>&1)"
  else
    raw="$(/usr/bin/jotta-cli version 2>&1)"
  fi
  printf '%s\n' "$raw" |
    sed -n "s/^[[:space:]]*${what} version[[:space:]]*:\?[[:space:]]*\([0-9][0-9._-]*\).*/\1/p" |
    head -n1
}

# The package version carries a packaging suffix the binary does not, so the
# binary's version must appear inside it. Empty never counts as a match.
versions_agree() { # versions_agree <from-binary> <from-package>
  [ -n "$1" ] && [ -n "$2" ] || { printf 'binary=%s package=%s\n' "${1:-<empty>}" "${2:-<empty>}"; return 1; }
  case "$2" in
    *"$1"*) return 0 ;;
  esac
  printf 'binary=%s package=%s\n' "$1" "$2"
  return 1
}

start_daemon_and_talk_to_it() {
  local user=jottatest uid rt
  id -u "$user" >/dev/null 2>&1 || useradd -m "$user" >/dev/null 2>&1
  uid="$(id -u "$user")" || { note "daemon skipped" "could not create a test user"; return 0; }

  # jottad runs per user and wants XDG_RUNTIME_DIR. Containers have no logind,
  # so create that directory by hand.
  rt="/run/user/$uid"
  mkdir -p "$rt" && chown "$user" "$rt" && chmod 700 "$rt"

  # JOTTAD_SYSTEMD=0 makes the shipped launcher fork the daemon directly
  # instead of going through `systemctl --user`, which a container lacks.
  su -l "$user" -c \
    "XDG_RUNTIME_DIR=$rt JOTTAD_SYSTEMD=0 JOTTAD_AUTOSTART=0 setsid run_jottad" \
    > "$WORK/jottad.log" 2>&1

  # Ready means "the CLI can talk to it", not "a file appeared where I guessed":
  # with no user session jottad listens on 127.0.0.1:14443 rather than on the
  # unix socket it uses under logind.
  local failed_before=$CHECKS_FAILED i ready=1
  for i in $(seq 1 "${JOTTA_DAEMON_TIMEOUT:-90}"); do
    if su -l "$user" -c "XDG_RUNTIME_DIR=$rt jotta-cli version" >/dev/null 2>&1; then
      ready=0
      break
    fi
    sleep 1
  done
  check "jotta-cli reaches jottad (within ${i}s)" test "$ready" -eq 0

  if [ -S "$rt/jottad/jottad.socket" ]; then
    note "daemon endpoint" "unix://$rt/jottad/jottad.socket"
  else
    note "daemon endpoint" "tcp://127.0.0.1:14443 (no user session, so no unix socket)"
  fi

  # The daemon and the CLI ship in the same package, so they must agree.
  local daemon_version
  daemon_version="$(cli_version_of jottad "$user" "$rt")"
  note "jottad version" "${daemon_version:-<none>}"
  check "jottad version matches the installed package" \
    versions_agree "$daemon_version" "$(installed_version)"

  # Nobody is logged in, so this reports that. Recorded, never fatal.
  note "jotta-cli status" \
    "$(su -l "$user" -c "XDG_RUNTIME_DIR=$rt jotta-cli status" 2>&1 | _oneline)"

  if [ "$CHECKS_FAILED" -gt "$failed_before" ]; then
    log "  --   jottad startup log:"
    sed 's/^/       /' "$WORK/jottad.log" | head -n 40
  fi

  su -l "$user" -c "XDG_RUNTIME_DIR=$rt JOTTAD_KILL=1 run_jottad" >/dev/null 2>&1
  return 0
}


# Run one step and report whether every check inside it passed, so a step
# that cannot possibly succeed does not drag a dozen dependent checks down
# with it. Shared by every install script.
step() { # step <function>
  local before=$CHECKS_FAILED
  "$1"
  [ "$CHECKS_FAILED" -eq "$before" ]
}

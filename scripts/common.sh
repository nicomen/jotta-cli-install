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
die()  { printf '  XX %s\n' "$*" >&2; exit 1; }

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

# rpm architecture name for the current machine.
rpm_arch() {
  case "$(uname -m)" in
    x86_64)          printf 'x86_64\n' ;;
    aarch64|arm64)   printf 'aarch64\n' ;;
    armv7l|armv7hl)  printf 'armv7hl\n' ;;
    i386|i486|i586|i686) printf 'i386\n' ;;
    *)               uname -m ;;
  esac
}

#!/usr/bin/env bash
#
# Host-side audit of the published signing keys and repository metadata.
# No container, no install — just: is what the docs point at actually the key
# that signs what the repo serves, on every host that serves it?
#
# Both hosts are checked because repo.jotta.us is still live and still linked
# from older documentation, and because /public.gpg still serves the 2017 RSA
# key that was rotated out on 2026-03-13.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

HOSTS=("$JOTTA_HOST" "$JOTTA_HOST_LEGACY")
KEY_PATHS=("$JOTTA_KEY_PATH" "$JOTTA_KEY_PATH_LEGACY")

slug() { printf '%s\n' "$1" | sed 's|^https\?://||; s|[^A-Za-z0-9]|_|g'; }

# --- keys -------------------------------------------------------------------

audit_keys() {
  info "Published keys"
  local host path url out fpr
  for host in "${HOSTS[@]}"; do
    for path in "${KEY_PATHS[@]}"; do
      url="${host}${path}"
      out="$WORK/key-$(slug "$url")"
      if ! curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"; then
        note "key ${url}" "not served"
        continue
      fi
      fpr="$(key_fingerprint "$out")"
      note "key ${url}" "${fpr:-<unparseable>}"

      if [ "$path" = "$JOTTA_KEY_PATH" ]; then
        # The documented key path must carry the pinned key on every host.
        check "key ${url} is the pinned signing key" \
          test "$fpr" = "$JOTTA_EXPECTED_FPR"
      else
        # The legacy path is expected to still serve the superseded key.
        # Flag it only if it silently starts serving something else again.
        check "key ${url} is the known superseded key (not the live one)" \
          test "$fpr" = "$JOTTA_LEGACY_FPR"
      fi
    done
  done
}

# --- key expiry -------------------------------------------------------------

audit_expiry() {
  info "Key expiry"
  local key="$WORK/key-$(slug "${JOTTA_HOST}${JOTTA_KEY_PATH}")"
  [ -s "$key" ] || { note "expiry" "pinned key unavailable"; return 0; }

  local expires now days
  expires="$(gpg --show-keys --with-colons "$key" 2>/dev/null |
    awk -F: '/^pub:/{print $7; exit}')"
  if [ -z "$expires" ]; then
    note "expiry" "pinned key does not expire"
    return 0
  fi
  now="$(date +%s)"
  days=$(( (expires - now) / 86400 ))
  note "expiry" "pinned key expires in ${days} days ($(date -u -d "@${expires}" '+%Y-%m-%d' 2>/dev/null))"
  check "key does not expire within ${JOTTA_EXPIRY_WARN_DAYS:-90} days" \
    test "$days" -gt "${JOTTA_EXPIRY_WARN_DAYS:-90}"
}

# --- metadata ---------------------------------------------------------------

metadata_urls() {
  local host="$1"
  printf '%s/debian/dists/%s/InRelease\n' "$host" "$JOTTA_DEB_SUITE"
  printf '%s/debian/dists/unstable/InRelease\n' "$host"
  printf '%s%s/repodata/repomd.xml.asc\n' "$host" "$JOTTA_RPM_PATH"
}

audit_metadata() {
  info "Metadata signatures"
  local keyring
  keyring="$(keyring_with "$WORK/key-$(slug "${JOTTA_HOST}${JOTTA_KEY_PATH}")")" ||
    die "could not build a verification keyring from the pinned key"
  export GNUPGHOME="$keyring"

  local host url out signer detached
  for host in "${HOSTS[@]}"; do
    while read -r url; do
      out="$WORK/meta-$(slug "$url")"
      if ! curl -fsSL --retry 3 -o "$out" "$url"; then
        note "metadata ${url}" "not served"
        continue
      fi

      detached=""
      case "$url" in
        *.asc)
          detached="$WORK/meta-$(slug "${url%.asc}")"
          curl -fsSL --retry 3 -o "$detached" "${url%.asc}" || detached=""
          ;;
      esac

      if [ -n "$detached" ]; then
        signer="$(signature_signer "$out" "$detached")"
        check "metadata ${url} verifies against the pinned key" \
          gpg --batch --verify "$out" "$detached"
      else
        signer="$(signature_signer "$out")"
        check "metadata ${url} verifies against the pinned key" \
          gpg --batch --verify "$out"
      fi
      note "metadata ${url} signer" "${signer:-<unknown>}"
    done < <(metadata_urls "$host")
  done

  unset GNUPGHOME
  rm -rf "$keyring"
}

# --- host consistency -------------------------------------------------------

audit_host_parity() {
  info "Host parity"
  [ "${#HOSTS[@]}" -ge 2 ] || return 0

  local url_a url_b a b
  while read -r url_a; do
    url_b="${JOTTA_HOST_LEGACY}${url_a#"$JOTTA_HOST"}"
    a="$WORK/meta-$(slug "$url_a")"
    b="$WORK/meta-$(slug "$url_b")"
    [ -s "$a" ] && [ -s "$b" ] || continue
    check "parity: ${url_a#"$JOTTA_HOST"} identical on both hosts" \
      cmp -s "$a" "$b"
  done < <(metadata_urls "$JOTTA_HOST")
}

# --- documented install lines still resolve ---------------------------------

audit_reachability() {
  info "Documented URLs resolve"
  local url
  for url in \
    "${JOTTA_HOST}${JOTTA_KEY_PATH}" \
    "${JOTTA_HOST}/debian/dists/${JOTTA_DEB_SUITE}/Release" \
    "${JOTTA_HOST}/debian/dists/${JOTTA_DEB_SUITE}/Release.gpg" \
    "${JOTTA_HOST}/debian/dists/${JOTTA_DEB_SUITE}/${JOTTA_DEB_COMPONENT}/binary-amd64/Packages" \
    "${JOTTA_HOST}${JOTTA_RPM_PATH}/repodata/repomd.xml" \
    "${JOTTA_HOST}/archives/VERSION"
  do
    check "reachable: ${url}" curl -fsS --retry 3 -o /dev/null "$url"
  done

  local version
  version="$(curl -fsSL "${JOTTA_HOST}/archives/VERSION" 2>/dev/null | tr -d '[:space:]')"
  note "published version" "${version:-<none>}"
}

main() {
  : > "$JOTTA_RESULTS"
  audit_keys
  audit_expiry
  audit_metadata
  audit_host_parity
  audit_reachability
  finish
}

main "$@"

#!/usr/bin/env bash
#
# Runs INSIDE a distro container as root.
#
# This is the four steps the documentation tells a user to follow:
#
#   1. add the repository (and its signing key)
#   2. update the package lists
#   3. install jotta-cli
#   4. run it, and see that it worked
#
# Each step also asserts the signing that is supposed to protect it. A final
# counter-check repeats the same four steps pinned to the superseded key and
# requires them to fail — otherwise "the signature was checked" means nothing.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAMILY=""        # debian | rpm
PKG_MGR=""       # apt | dnf | yum | zypper
RPM_REPO_DIR=""  # zypper reads /etc/zypp/repos.d, dnf and yum /etc/yum.repos.d

# ===========================================================================
# Every apt/dnf/yum/zypper difference lives in this section, so the four steps
# below read the same on every distro.
# ===========================================================================

detect_platform() {
  PKG_MGR="$(detect_pkg_mgr)" || die "no supported package manager found"
  case "$PKG_MGR" in
    apt)     FAMILY=debian ;;
    zypper)  FAMILY=rpm; RPM_REPO_DIR=/etc/zypp/repos.d ;;
    dnf|yum) FAMILY=rpm; RPM_REPO_DIR=/etc/yum.repos.d ;;
  esac
  [ -n "$RPM_REPO_DIR" ] && mkdir -p "$RPM_REPO_DIR"
  return 0
}

# Write a repository definition that trusts exactly one key.
repo_add() { # repo_add <repo-id> <binary-key-file>
  local id="$1" key="$2"
  case "$FAMILY" in
    debian)
      mkdir -p /etc/apt/sources.list.d
      install -D -m644 "$key" "/usr/share/keyrings/${id}.gpg"
      printf 'deb [signed-by=/usr/share/keyrings/%s.gpg] %s/debian %s %s\n' \
        "$id" "$JOTTA_HOST" "$JOTTA_DEB_SUITE" "$JOTTA_DEB_COMPONENT" \
        > "/etc/apt/sources.list.d/${id}.list"
      ;;
    rpm)
      # rpm and friends want the key ASCII-armored.
      armor_key "$key" "$WORK/${id}.asc" || return 1
      rpm --import "$WORK/${id}.asc" || return 1
      cat > "${RPM_REPO_DIR}/${id}.repo" <<EOF
[${id}]
name=Jottacloud CLI (${id})
baseurl=${JOTTA_HOST}${JOTTA_RPM_PATH}
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file://${WORK}/${id}.asc
EOF
      ;;
  esac
}

repo_refresh() { # repo_refresh <repo-id>
  case "$PKG_MGR" in
    apt)    apt_update_repo "$1" ;;
    dnf)    dnf -y --repo="$1" makecache ;;
    yum)    yum -y --disablerepo='*' --enablerepo="$1" makecache ;;
    zypper) zypper --non-interactive refresh "$1" ;;
  esac
}

# Install the package. Only the jotta repository provides it, so whichever
# repository is configured at the time is the one under test.
repo_install() {
  case "$PKG_MGR" in
    apt)    apt-get install -y --no-install-recommends "$JOTTA_PACKAGE" ;;
    dnf|yum) "$PKG_MGR" -y install "$JOTTA_PACKAGE" ;;
    zypper) zypper --non-interactive install "$JOTTA_PACKAGE" ;;
  esac
}

repo_uninstall() {
  case "$PKG_MGR" in
    apt)     apt-get remove -y --purge "$JOTTA_PACKAGE" ;;
    dnf|yum) "$PKG_MGR" -y remove "$JOTTA_PACKAGE" ;;
    zypper)  zypper --non-interactive remove "$JOTTA_PACKAGE" ;;
  esac
}

# Forget a repository completely: its definition, its key, and any metadata
# already cached from it. Without this the next step could quietly succeed
# using what the previous one left behind.
repo_forget() { # repo_forget <repo-id> <key-fingerprint>
  local id="$1" fpr="$2" short
  case "$FAMILY" in
    debian)
      rm -f "/etc/apt/sources.list.d/${id}.list" "/usr/share/keyrings/${id}.gpg"
      rm -f /var/lib/apt/lists/*jotta*
      ;;
    rpm)
      rm -f "${RPM_REPO_DIR}/${id}.repo"
      case "$PKG_MGR" in
        dnf|yum) "$PKG_MGR" clean metadata >/dev/null 2>&1 ;;
        zypper)  zypper --non-interactive clean --metadata >/dev/null 2>&1 ;;
      esac
      # rpm names imported keys after the last 8 hex of the key id.
      short="$(printf '%s' "${fpr: -8}" | tr 'A-Z' 'a-z')"
      rpm -qa 'gpg-pubkey*' 2>/dev/null | grep -i -- "$short" |
        xargs -r rpm -e 2>/dev/null
      ;;
  esac
  return 0
}

package_installed() {
  case "$FAMILY" in
    debian) dpkg-query -W -f='${Status}' "$JOTTA_PACKAGE" 2>/dev/null |
              grep -q '^install ok installed' ;;
    rpm)    rpm -q "$JOTTA_PACKAGE" >/dev/null 2>&1 ;;
  esac
}

installed_version() {
  case "$FAMILY" in
    debian) dpkg-query -W -f='${Version}' "$JOTTA_PACKAGE" 2>/dev/null ;;
    rpm)    rpm -q --qf '%{VERSION}-%{RELEASE}' "$JOTTA_PACKAGE" 2>/dev/null ;;
  esac
}

# URL of the signed metadata file, and of the data it signs (empty when the
# signature is inline, as in a Debian InRelease).
metadata_signature_url() {
  case "$FAMILY" in
    debian) printf '%s/debian/dists/%s/InRelease\n' "$JOTTA_HOST" "$JOTTA_DEB_SUITE" ;;
    rpm)    printf '%s%s/repodata/repomd.xml.asc\n' "$JOTTA_HOST" "$JOTTA_RPM_PATH" ;;
  esac
}

# ===========================================================================
# Step 0 — make the container able to run the test at all
# ===========================================================================

bootstrap() {
  detect_platform

  info "Target: $(os_pretty_name) [$(pkg_arch)] via ${PKG_MGR}"
  note "os" "$(os_pretty_name)"
  note "arch" "$(pkg_arch) (kernel: $(uname -m))"
  note "pkg_mgr" "$PKG_MGR"

  # One metadata refresh, then install only the tools that are missing.
  case "$PKG_MGR" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      use_debian_archive_if_eol
      apt-get update -qq
      ensure_commands apt \
        curl:curl gpg:gnupg ps:procps killall:psmisc su:util-linux useradd:passwd
      ;;
    dnf|yum)
      ensure_commands "$PKG_MGR" \
        curl:curl gpg:gnupg2 ps:procps-ng killall:psmisc \
        su:util-linux useradd:shadow-utils
      ;;
    zypper)
      zypper --non-interactive --quiet refresh >/dev/null
      ensure_commands zypper \
        curl:curl gpg:gpg2 ps:procps killall:psmisc su:util-linux useradd:shadow
      ;;
  esac
}

# A Debian release past EOL is served only from archive.debian.org. deb.debian.org
# keeps advertising indices whose .deb files have been removed, so apt resolves
# packages and then 404s on the download.
use_debian_archive_if_eol() {
  local id version
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || return 0
  id="${ID:-}"; version="${VERSION_ID:-}"
  [ "$id" = debian ] || return 0
  case "$version" in ''|*[!0-9]*) return 0 ;; esac
  [ "$version" -le "${JOTTA_DEBIAN_EOL_BEFORE:-11}" ] || return 0

  note "apt sources" "Debian ${version} is EOL — using archive.debian.org (security.debian.org for -security)"
  # archive.debian.org never mirrored debian-security at all; that suite stays
  # on security.debian.org even after the release itself moves to archive.
  sed -i -e 's|[a-z.]*\.debian\.org/debian-security|security.debian.org/debian-security|g' \
         -e 's|deb\.debian\.org/debian|archive.debian.org/debian|g' \
         /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null
  # Archived Release files are long past their Valid-Until date.
  echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99jotta-archive
  return 0
}

# ===========================================================================
# Step 1 — add the repository
# ===========================================================================

add_repo() {
  info "1. Add the repository"

  check "key downloads from ${JOTTA_KEY_URL}" \
    curl -fsSL --retry 3 --retry-delay 2 -o "$WORK/jotta.gpg" "$JOTTA_KEY_URL"
  [ -s "$WORK/jotta.gpg" ] || die "could not download the signing key"

  # Whatever the key says about itself, it must be the one we expect.
  check "key has the pinned fingerprint ${JOTTA_EXPECTED_FPR}" \
    assert_key_fingerprint "$WORK/jotta.gpg"
  note "key uid" "$(gpg --show-keys --with-colons "$WORK/jotta.gpg" 2>/dev/null |
    awk -F: '/^uid:/{print $10; exit}')"

  local before=$CHECKS_FAILED
  check "repository configured to trust only that key" \
    repo_add jotta-cli "$WORK/jotta.gpg"

  # The most likely reason on an older distro is the key algorithm: rpm gained
  # EdDSA (ed25519) support in 4.15, so EL8-era rpm cannot import this key.
  if [ "$CHECKS_FAILED" -gt "$before" ] && [ "$FAMILY" = rpm ]; then
    note "rpm version" "$(rpm --version 2>&1)"
    note "likely cause" \
      "rpm before 4.15 cannot import EdDSA keys; this repository signs with ed25519"
  fi
}

# ===========================================================================
# Step 2 — update
# ===========================================================================

update_repo() {
  info "2. Update"

  check "package manager accepts the repository" repo_refresh jotta-cli

  # Independently of what the package manager decided, check the signature
  # ourselves, so a package manager that only warns cannot hide a bad one.
  local url sig data keyring
  url="$(metadata_signature_url)"
  sig="$WORK/metadata.sig"
  data=""

  check "metadata downloads" curl -fsSL --retry 3 -o "$sig" "$url"
  if [ "$FAMILY" = rpm ]; then
    data="$WORK/metadata"
    check "signed metadata downloads" curl -fsSL --retry 3 -o "$data" "${url%.asc}"
  fi

  keyring="$(keyring_with "$WORK/jotta.gpg")" || die "could not build a keyring"
  check "metadata is signed by the pinned key" \
    env GNUPGHOME="$keyring" gpg --batch --verify "$sig" ${data:+"$data"}
  note "metadata signer" \
    "$(GNUPGHOME="$keyring" signature_signer "$sig" ${data:+"$data"})"
  [ "$FAMILY" = debian ] && {
    note "metadata date" "$(sed -n 's/^Date: //p' "$sig" | head -n1)"
    note "metadata architectures" "$(sed -n 's/^Architectures: //p' "$sig" | head -n1)"
  }
  rm -rf "$keyring"
  return 0
}

# ===========================================================================
# Step 3 — install
# ===========================================================================

install_cli() {
  info "3. Install ${JOTTA_PACKAGE}"

  check "installs with signature checking enabled" repo_install
  check "package is installed" package_installed
  note "installed version" "$(installed_version)"

  verify_what_landed
}

# The package manager says it verified a signature. Check that the bytes on
# disk are the ones the signed metadata vouches for.
verify_what_landed() {
  package_installed || {
    note "artifact checks skipped" "${JOTTA_PACKAGE} is not installed"
    return 1
  }
  case "$FAMILY" in
    debian)
      # Debian packages are not individually signed; trust runs
      # InRelease -> Packages -> SHA256 of the .deb. Walk that last hop.
      mkdir -p "$WORK/dl" && chmod 777 "$WORK" "$WORK/dl"
      ( cd "$WORK/dl" && apt-get download "$JOTTA_PACKAGE" >/dev/null 2>&1 )
      local deb want got
      deb="$(find "$WORK/dl" -maxdepth 1 -name '*.deb' | head -n1)"
      if [ -z "$deb" ]; then
        note "digest check skipped" "apt-get download produced no file"
        return 0
      fi
      want="$(apt-cache show "$JOTTA_PACKAGE" | awk '/^SHA256:/{print $2; exit}')"
      got="$(sha256sum "$deb" | cut -d' ' -f1)"
      check ".deb digest matches the signed Packages index" test "$want" = "$got"
      note "package sha256" "$got"
      ;;
    rpm)
      # rpm prints "(none)" for absent tags, so require a tag with content.
      local sig
      sig="$(rpm -q --qf '%{SIGPGP:pgpsig}\n%{SIGGPG:pgpsig}\n%{RSAHEADER:pgpsig}\n%{DSAHEADER:pgpsig}\n' \
        "$JOTTA_PACKAGE" 2>/dev/null | grep -vxF '(none)' | grep -v '^$' | head -n1)"
      check "installed rpm carries a signature" test -n "$sig"
      note "package signature" "${sig:-(none)}"

      local arch file
      arch="$(rpm_arch)"
      file="$(curl -fsSL "${JOTTA_HOST}${JOTTA_RPM_PATH}/" |
        grep -o "jotta-cli-[0-9][^\"]*\.${arch}\.rpm" | sort -V | tail -n1)"
      if [ -z "$file" ]; then
        note "checksig skipped" "no ${arch} rpm in the repository index"
        return 0
      fi
      if curl -fsSL --retry 3 -o "$WORK/pkg.rpm" "${JOTTA_HOST}${JOTTA_RPM_PATH}/${file}"; then
        check "rpm --checksig on ${file}" rpm --checksig "$WORK/pkg.rpm"
      else
        note "checksig skipped" "could not download ${file}"
      fi
      ;;
  esac
  return 0
}

# ===========================================================================
# Step 4 — run it
# ===========================================================================

run_cli() {
  info "4. Run it"
  check_binaries_and_run  # shared with the AUR test: common.sh
}

# ===========================================================================
# Counter-check — the same four steps, pinned to the superseded key
#
# Without this the run above only proves that installing works, not that the
# signature was ever what made it work.
# ===========================================================================

wrong_key_is_refused() {
  info "Counter-check: the superseded key must not work"

  curl -fsSL --retry 3 -o "$WORK/legacy.gpg" \
    "${JOTTA_HOST}${JOTTA_KEY_PATH_LEGACY}" 2>/dev/null
  if [ ! -s "$WORK/legacy.gpg" ]; then
    note "counter-check skipped" \
      "no key served at ${JOTTA_HOST}${JOTTA_KEY_PATH_LEGACY}"
    return 0
  fi

  # Start from nothing: no package, no good repository, no trusted good key.
  repo_uninstall >/dev/null 2>&1
  repo_forget jotta-cli "$JOTTA_EXPECTED_FPR"
  check_fails "package removed before the counter-check" package_installed

  repo_add jotta-legacy "$WORK/legacy.gpg"

  # The refresh is only recorded: dnf5 prints "repomd.xml GPG signature
  # verification error" and still exits 0, so it cannot carry the assertion.
  note "refresh output" \
    "$(repo_refresh jotta-legacy 2>&1 | grep -iE 'signature|key|not signed|E:' | _oneline)"

  check_fails "install from the superseded-key repository is refused" repo_install
  check_fails "nothing was installed by the refused attempt" package_installed

  repo_forget jotta-legacy "$JOTTA_LEGACY_FPR"
}

# ===========================================================================

main() {
  : > "$JOTTA_RESULTS"

  step bootstrap            # make the container able to run the test

  if step add_repo &&       # 1. add the repository and its key
     step update_repo &&    # 2. update
     step install_cli; then # 3. install jotta-cli
     step run_cli           # 4. run it, and see that it worked
  else
    note "remaining steps skipped" "an earlier step failed; see the first failure above"
  fi

  step wrong_key_is_refused # and prove the signature is what made that work

  finish
}

main "$@"

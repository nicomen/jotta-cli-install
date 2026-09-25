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
# Each step also asserts the signing that is supposed to protect it.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

# Must happen before anything else touches dnf/rpm -- see the comment on
# the function itself (common.sh) for why.
maybe_reexec_for_32bit_rootfs "$@"

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
    dnf)    dnf -y $(dnf_forcearch_args) --repo="$1" makecache ;;
    yum)    yum -y $(dnf_forcearch_args) --disablerepo='*' --enablerepo="$1" makecache ;;
    zypper) zypper --non-interactive refresh "$1" ;;
  esac
}

# Install the package. Only the jotta repository provides it, so whichever
# repository is configured at the time is the one under test.
repo_install() {
  case "$PKG_MGR" in
    apt)    apt-get install -y --no-install-recommends "$JOTTA_PACKAGE" ;;
    dnf|yum) "$PKG_MGR" -y $(dnf_forcearch_args) install "$JOTTA_PACKAGE" ;;
    zypper) zypper --non-interactive install "$JOTTA_PACKAGE" ;;
  esac
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

  note_os_lifecycle

  # One metadata refresh, then install only the tools that are missing.
  case "$PKG_MGR" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      use_debian_archive_if_eol
      apt-get update -qq
      ensure_commands apt \
        curl:curl gpg:gnupg ps:procps killall:psmisc su:util-linux \
        useradd:passwd awk:gawk
      ;;
    dnf|yum)
      ensure_commands "$PKG_MGR" \
        curl:curl gpg:gnupg2 ps:procps-ng killall:psmisc \
        su:util-linux useradd:shadow-utils awk:gawk
      ;;
    zypper)
      zypper --non-interactive --quiet refresh >/dev/null
      # Tumbleweed's base image, unlike Leap's, ships without awk at all.
      ensure_commands zypper \
        curl:curl gpg:gpg2 ps:procps killall:psmisc su:util-linux \
        useradd:shadow awk:gawk
      ;;
  esac

  # The very first call to this (top of the script, before anything is
  # installed) only succeeds on images that already ship linux32 -- found
  # AlmaLinux 10's default image doesn't. su:util-linux is required above on
  # every branch, so by now it's guaranteed present; try again. Re-exec
  # restarts the whole script, so bootstrap() (and this install) runs a
  # second time too, but ensure_commands is a no-op the second time --
  # nothing new to install -- so the only cost is repeating it once.
  maybe_reexec_for_32bit_rootfs
}

# Once a Debian release's free/public support ends (regular, then LTS — see
# https://wiki.debian.org/LTS; anything after that is paid Extended LTS on
# separate infrastructure this doesn't have access to), deb.debian.org drops
# it entirely and only archive.debian.org still serves the main suite.
# "eol" here means "off deb.debian.org," not "unsupported" -- ELTS may well
# still cover it.
use_debian_archive_if_eol() {
  local id version
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || return 0
  id="${ID:-}"; version="${VERSION_ID:-}"
  [ "$id" = debian ] || return 0
  case "$version" in ''|*[!0-9]*) return 0 ;; esac
  [ "$version" -le "${JOTTA_DEBIAN_EOL_BEFORE:-11}" ] || return 0

  note "apt sources" "Debian ${version} is off deb.debian.org — main via archive.debian.org, security stays on security.debian.org"
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

  finish
}

main "$@"

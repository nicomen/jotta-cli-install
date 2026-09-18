#!/usr/bin/env bash
#
# Runs INSIDE a distro container as root.
#
# Installs jotta-cli from the public Jottacloud repository the way the official
# documentation tells users to, with signature verification left switched on,
# and proves that the signing actually holds:
#
#   1. the published key has the pinned fingerprint
#   2. the repository metadata is signed by that key
#   3. a repo pinned to the *superseded* key is refused (negative test)
#   4. the package installs with gpgcheck enabled
#   5. the installed package carries a valid signature / matching digest
#   6. the daemon starts and the CLI can talk to it
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAMILY=""          # debian | rpm
PKG_MGR=""
RPM_REPO_DIR=""    # zypper reads /etc/zypp/repos.d, dnf/yum /etc/yum.repos.d

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

bootstrap() {
  PKG_MGR="$(detect_pkg_mgr)" || die "no supported package manager found"
  case "$PKG_MGR" in
    apt)     FAMILY=debian ;;
    zypper)  FAMILY=rpm; RPM_REPO_DIR=/etc/zypp/repos.d ;;
    dnf|yum) FAMILY=rpm; RPM_REPO_DIR=/etc/yum.repos.d ;;
  esac
  [ -n "$RPM_REPO_DIR" ] && mkdir -p "$RPM_REPO_DIR"

  info "Target: $(os_pretty_name) [$(uname -m)] via ${PKG_MGR}"
  note "os" "$(os_pretty_name)"
  note "arch" "$(uname -m)"
  note "pkg_mgr" "$PKG_MGR"

  case "$PKG_MGR" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq --no-install-recommends \
        curl gnupg ca-certificates apt-transport-https procps psmisc >/dev/null
      ;;
    dnf)
      dnf -y -q install curl gnupg2 ca-certificates procps-ng psmisc shadow-utils >/dev/null
      ;;
    yum)
      yum -y -q install curl gnupg2 ca-certificates procps-ng psmisc shadow-utils >/dev/null
      ;;
    zypper)
      zypper --non-interactive --quiet refresh >/dev/null
      zypper --non-interactive --quiet install curl gpg2 ca-certificates procps psmisc shadow >/dev/null
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 1. Key identity
# ---------------------------------------------------------------------------

fetch_keys() {
  info "Signing keys"

  check "key: ${JOTTA_KEY_URL} downloads" \
    curl -fsSL --retry 3 --retry-delay 2 -o "$WORK/jotta.gpg" "$JOTTA_KEY_URL"
  [ -s "$WORK/jotta.gpg" ] || die "could not download the signing key"

  check "key: fingerprint is ${JOTTA_EXPECTED_FPR}" \
    assert_key_fingerprint "$WORK/jotta.gpg"

  note "key: uid" "$(gpg --show-keys --with-colons "$WORK/jotta.gpg" 2>/dev/null |
    awk -F: '/^uid:/{print $10; exit}')"

  # The superseded key, used below to prove that a wrong key is rejected.
  curl -fsSL --retry 3 -o "$WORK/legacy.gpg" \
    "${JOTTA_HOST}${JOTTA_KEY_PATH_LEGACY}" 2>/dev/null || true

  armor_key "$WORK/jotta.gpg" "$WORK/jotta.asc" ||
    die "could not ASCII-armor the signing key"
  if [ -s "$WORK/legacy.gpg" ]; then
    armor_key "$WORK/legacy.gpg" "$WORK/legacy.asc" || true
  fi
}

# ---------------------------------------------------------------------------
# 2. Repository metadata signature (independent of the package manager)
# ---------------------------------------------------------------------------

verify_metadata() {
  info "Repository metadata signature"

  local home
  home="$(keyring_with "$WORK/jotta.gpg")" || die "could not build verification keyring"

  if [ "$FAMILY" = debian ]; then
    local url="${JOTTA_HOST}/debian/dists/${JOTTA_DEB_SUITE}/InRelease"
    check "metadata: InRelease downloads" \
      curl -fsSL --retry 3 -o "$WORK/InRelease" "$url"
    check "metadata: InRelease signed by pinned key" \
      env GNUPGHOME="$home" bash -c \
      'gpg --batch --verify "$1" >/dev/null 2>&1' _ "$WORK/InRelease"
    note "metadata: signer" "$(GNUPGHOME="$home" signature_signer "$WORK/InRelease")"
    note "metadata: date" "$(sed -n 's/^Date: //p' "$WORK/InRelease" | head -n1)"
    note "metadata: architectures" \
      "$(sed -n 's/^Architectures: //p' "$WORK/InRelease" | head -n1)"
  else
    local base="${JOTTA_HOST}${JOTTA_RPM_PATH}/repodata"
    check "metadata: repomd.xml downloads" \
      curl -fsSL --retry 3 -o "$WORK/repomd.xml" "$base/repomd.xml"
    check "metadata: repomd.xml.asc downloads" \
      curl -fsSL --retry 3 -o "$WORK/repomd.xml.asc" "$base/repomd.xml.asc"
    check "metadata: repomd.xml signed by pinned key" \
      env GNUPGHOME="$home" bash -c \
      'gpg --batch --verify "$1" "$2" >/dev/null 2>&1' _ \
      "$WORK/repomd.xml.asc" "$WORK/repomd.xml"
    note "metadata: signer" \
      "$(GNUPGHOME="$home" signature_signer "$WORK/repomd.xml.asc" "$WORK/repomd.xml")"
  fi

  rm -rf "$home"
}

# ---------------------------------------------------------------------------
# 3. Negative test: the superseded key must NOT validate the repository
# ---------------------------------------------------------------------------

negative_test() {
  info "Negative test: repo pinned to the superseded key must be refused"

  if [ ! -s "$WORK/legacy.gpg" ]; then
    note "negative: skipped" "legacy key ${JOTTA_HOST}${JOTTA_KEY_PATH_LEGACY} not available"
    return 0
  fi

  case "$FAMILY" in
    debian)
      mkdir -p /etc/apt/sources.list.d
      install -D -m644 "$WORK/legacy.gpg" /usr/share/keyrings/jotta-legacy.gpg
      printf 'deb [signed-by=/usr/share/keyrings/jotta-legacy.gpg] %s/debian %s %s\n' \
        "$JOTTA_HOST" "$JOTTA_DEB_SUITE" "$JOTTA_DEB_COMPONENT" \
        > /etc/apt/sources.list.d/jotta-cli-legacy.list
      check_fails "negative: apt-get update rejects the superseded key" \
        apt-get update
      rm -f /etc/apt/sources.list.d/jotta-cli-legacy.list /usr/share/keyrings/jotta-legacy.gpg
      apt-get update -qq
      ;;
    rpm)
      [ -s "$WORK/legacy.asc" ] || { note "negative: skipped" "could not armor legacy key"; return 0; }
      rpm --import "$WORK/legacy.asc" 2>/dev/null || true
      write_rpm_repo "$RPM_REPO_DIR/jotta-cli-legacy.repo" jotta-cli-legacy \
        "file://$WORK/legacy.asc"
      case "$PKG_MGR" in
        dnf|yum) check_fails "negative: ${PKG_MGR} makecache rejects the superseded key" \
                   "$PKG_MGR" -y --disablerepo='*' --enablerepo=jotta-cli-legacy makecache ;;
        zypper)  check_fails "negative: zypper refresh rejects the superseded key" \
                   zypper --non-interactive refresh jotta-cli-legacy ;;
      esac
      rm -f "$RPM_REPO_DIR/jotta-cli-legacy.repo"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 4. Install, with signature checking on
# ---------------------------------------------------------------------------

write_rpm_repo() { # write_rpm_repo <file> <id> <gpgkey-url>
  cat > "$1" <<EOF
[$2]
name=Jottacloud CLI ($2)
baseurl=${JOTTA_HOST}${JOTTA_RPM_PATH}
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$3
EOF
}

install_package() {
  info "Install ${JOTTA_PACKAGE}"

  case "$FAMILY" in
    debian)
      mkdir -p /etc/apt/sources.list.d
      install -D -m644 "$WORK/jotta.gpg" /usr/share/keyrings/jotta.gpg
      printf 'deb [signed-by=/usr/share/keyrings/jotta.gpg] %s/debian %s %s\n' \
        "$JOTTA_HOST" "$JOTTA_DEB_SUITE" "$JOTTA_DEB_COMPONENT" \
        > /etc/apt/sources.list.d/jotta-cli.list
      check "install: apt-get update accepts the repository" apt-get update
      check "install: apt-get install ${JOTTA_PACKAGE}" \
        apt-get install -y --no-install-recommends "$JOTTA_PACKAGE"
      ;;
    rpm)
      rpm --import "$WORK/jotta.asc"
      write_rpm_repo "$RPM_REPO_DIR/jotta-cli.repo" jotta-cli "file://$WORK/jotta.asc"
      case "$PKG_MGR" in
        dnf|yum)
          check "install: ${PKG_MGR} makecache accepts the repository" \
            "$PKG_MGR" -y --disablerepo='*' --enablerepo=jotta-cli makecache
          check "install: ${PKG_MGR} install ${JOTTA_PACKAGE}" \
            "$PKG_MGR" -y install "$JOTTA_PACKAGE"
          ;;
        zypper)
          check "install: zypper refresh accepts the repository" \
            zypper --non-interactive refresh jotta-cli
          check "install: zypper install ${JOTTA_PACKAGE}" \
            zypper --non-interactive install "$JOTTA_PACKAGE"
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 5. The installed artifact really is the signed one
# ---------------------------------------------------------------------------

verify_installed_package() {
  info "Installed package integrity"

  local pkg_version=""
  case "$FAMILY" in
    debian)
      pkg_version="$(dpkg-query -W -f='${Version}' "$JOTTA_PACKAGE" 2>/dev/null)"

      # Debian packages are not individually signed; trust flows from the
      # signed InRelease -> Packages -> SHA256 of the .deb. Check that chain.
      # apt-get download drops privileges to _apt, so it needs a directory
      # that user can write to.
      mkdir -p "$WORK/dl" && chmod 777 "$WORK" "$WORK/dl"
      ( cd "$WORK/dl" && apt-get download "$JOTTA_PACKAGE" >/dev/null 2>&1 )
      local deb want got
      deb="$(find "$WORK/dl" -maxdepth 1 -name '*.deb' | head -n1)"
      if [ -n "$deb" ]; then
        want="$(apt-cache show "$JOTTA_PACKAGE" | awk '/^SHA256:/{print $2; exit}')"
        got="$(sha256sum "$deb" | cut -d' ' -f1)"
        check "package: .deb digest matches the signed Packages index" \
          test "$want" = "$got"
        note "package: sha256" "$got"
      else
        note "package: digest check skipped" "apt-get download produced no file"
      fi
      ;;
    rpm)
      pkg_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$JOTTA_PACKAGE" 2>/dev/null)"

      # rpm prints "(none)" for absent tags, so require at least one tag that
      # holds something else.
      local sig
      sig="$(rpm -q --qf '%{SIGPGP:pgpsig}\n%{SIGGPG:pgpsig}\n%{RSAHEADER:pgpsig}\n%{DSAHEADER:pgpsig}\n' \
        "$JOTTA_PACKAGE" 2>/dev/null | grep -vxF '(none)' | grep -v '^$' | head -n1)"
      check "package: installed rpm carries a signature" test -n "$sig"
      note "package: signature" "${sig:-(none)}"

      # And check a freshly downloaded rpm end to end with rpm --checksig.
      local arch file url
      arch="$(rpm_arch)"
      file="$(curl -fsSL "${JOTTA_HOST}${JOTTA_RPM_PATH}/" |
        grep -o "jotta-cli-[0-9][^\"]*\.${arch}\.rpm" | sort -V | tail -n1)"
      if [ -n "$file" ]; then
        url="${JOTTA_HOST}${JOTTA_RPM_PATH}/${file}"
        if curl -fsSL --retry 3 -o "$WORK/pkg.rpm" "$url"; then
          check "package: rpm --checksig on ${file}" rpm --checksig "$WORK/pkg.rpm"
        else
          note "package: checksig skipped" "could not download $url"
        fi
      else
        note "package: checksig skipped" "no ${arch} rpm found in the repo index"
      fi
      ;;
  esac

  note "package: version" "${pkg_version:-<not installed>}"

  check "binaries: jotta-cli present" test -x /usr/bin/jotta-cli
  check "binaries: jottad present"    test -x /usr/bin/jottad
  check "binaries: run_jottad present" test -x /usr/bin/run_jottad

  # The client version string must match what the package manager installed.
  local cli_version
  cli_version="$(/usr/bin/jotta-cli version 2>/dev/null |
    sed -n 's/^jotta-cli version //p' | head -n1)"
  note "binaries: jotta-cli version" "${cli_version:-<none>}"
  check "binaries: CLI version matches package version" \
    bash -c '[ -n "$1" ] && [ -n "$2" ] &&
             case "$2" in *"$1"*) exit 0 ;; esac
             echo "cli=${1:-<empty>} pkg=${2:-<empty>}"; exit 1' \
    _ "$cli_version" "$pkg_version"
}

# ---------------------------------------------------------------------------
# 6. Daemon smoke test
# ---------------------------------------------------------------------------

smoke_daemon() {
  info "Daemon smoke test"

  local user=jottatest uid rt
  id -u "$user" >/dev/null 2>&1 || useradd -m "$user" >/dev/null 2>&1
  uid="$(id -u "$user")" || { note "daemon: skipped" "could not create test user"; return 0; }

  # jottad runs per-user and puts its unix socket under XDG_RUNTIME_DIR.
  # Containers have no logind, so create the directory by hand.
  rt="/run/user/$uid"
  mkdir -p "$rt"
  chown "$user" "$rt"
  chmod 700 "$rt"

  # JOTTAD_SYSTEMD=0 makes the shipped launcher fork the daemon directly
  # instead of going through `systemctl --user`, which containers lack.
  su -l "$user" -c \
    "XDG_RUNTIME_DIR=$rt JOTTAD_SYSTEMD=0 JOTTAD_AUTOSTART=0 setsid run_jottad" \
    > "$WORK/jottad.log" 2>&1

  local socket="$rt/jottad/jottad.socket" i
  for i in $(seq 1 60); do
    [ -S "$socket" ] && break
    sleep 1
  done

  local failed_before=$CHECKS_FAILED
  check "daemon: socket appears at ${socket}" test -S "$socket"
  check "daemon: jotta-cli version talks to jottad" \
    su -l "$user" -c "XDG_RUNTIME_DIR=$rt jotta-cli version"

  # Not logged in, so this is expected to report "not logged in" rather than
  # succeed. Record it for the report, never fail on it.
  note "daemon: jotta-cli status" \
    "$(su -l "$user" -c "XDG_RUNTIME_DIR=$rt jotta-cli status" 2>&1 | _oneline)"

  if [ "$CHECKS_FAILED" -gt "$failed_before" ]; then
    log "  --   jottad startup log:"
    sed 's/^/       /' "$WORK/jottad.log" | head -n 40
  fi

  su -l "$user" -c "XDG_RUNTIME_DIR=$rt JOTTAD_KILL=1 run_jottad" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------

main() {
  : > "$JOTTA_RESULTS"
  bootstrap
  fetch_keys
  verify_metadata
  negative_test
  install_package
  verify_installed_package
  smoke_daemon
  finish
}

main "$@"

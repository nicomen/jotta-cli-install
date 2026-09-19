#!/usr/bin/env bash
#
# Runs INSIDE an Arch Linux container as root.
#
# jotta maintains an official AUR package (aur.archlinux.org/packages/jotta-cli,
# maintainer "jottacloud"), but it is a fundamentally different trust model
# from the apt/dnf/zypper repositories tested by test-install.sh:
#
#   - there is no repository and no live GPG check at install time
#   - the PKGBUILD instead pins a SHA256 of one specific .deb, fetched from
#     the legacy host (repo.jotta.us), and makepkg refuses to build if the
#     download doesn't match that pin
#
# So the four steps become: fetch the PKGBUILD, build it (which is where the
# pinned hash is actually checked), install the result, run it. A wrong-key test
# at the end corrupts the pin and requires the build to fail — otherwise the
# pin would not be proven to do anything.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
. "$HERE/common.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

AUR_PACKAGE="${AUR_PACKAGE:-jotta-cli}"
AUR_SNAPSHOT="${AUR_SNAPSHOT:-https://aur.archlinux.org/cgit/aur.git/snapshot/${AUR_PACKAGE}.tar.gz}"
BUILD_USER="builder"
BUILD_DIR="$WORK/${AUR_PACKAGE}"

# Required by check_binaries_and_run (common.sh).
installed_version() { pacman -Q "$AUR_PACKAGE" 2>/dev/null | awk '{print $2}'; }
package_installed()  { pacman -Q "$AUR_PACKAGE" >/dev/null 2>&1; }

# makepkg must run as an unprivileged user. `su -l` gives it a real login
# shell (HOME, PATH) rather than inheriting root's.
as_builder() { su -l "$BUILD_USER" -c "$1"; }

bootstrap() {
  info "Target: Arch Linux [$(uname -m)] via makepkg"
  note "os" "$(os_pretty_name)"
  note "arch" "$(uname -m)"

  pacman -Sy --noconfirm --quiet >/dev/null
  # --needed skips whatever is already there, same intent as ensure_commands
  # in common.sh, but pacman does it natively so there is no need to reinvent
  # that logic for a fifth package manager.
  # fakeroot: required by makepkg to run package() with faked ownership.
  # debugedit: the PKGBUILD doesn't disable debug-package generation, and
  # without it makepkg aborts before even downloading anything ("Cannot find
  # the debugedit binary") -- found by actually running this in CI.
  pacman -S --needed --noconfirm --quiet fakeroot debugedit curl git sudo >/dev/null

  id -u "$BUILD_USER" >/dev/null 2>&1 || useradd -m "$BUILD_USER"
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$BUILD_USER" > "/etc/sudoers.d/${BUILD_USER}"
  mkdir -p "$WORK"
  chown -R "$BUILD_USER" "$WORK"
}

# ===========================================================================
# Step 1 — fetch the PKGBUILD
# ===========================================================================

fetch_pkgbuild() {
  info "1. Fetch the PKGBUILD"

  check "PKGBUILD snapshot downloads from ${AUR_SNAPSHOT}" \
    curl -fsSL --retry 3 --retry-delay 2 -o "$WORK/pkg.tar.gz" "$AUR_SNAPSHOT"
  check "snapshot extracts" tar -xzf "$WORK/pkg.tar.gz" -C "$WORK"
  chown -R "$BUILD_USER" "$WORK"

  check "PKGBUILD is present" test -f "$BUILD_DIR/PKGBUILD"

  note "maintainer" "$(sed -n 's/^# Maintainer: //p' "$BUILD_DIR/PKGBUILD" 2>/dev/null | head -n1)"
  note "pinned version" \
    "$(sed -n "s/^pkgver=['\"]\{0,1\}\\([^'\"]*\\).*/\\1/p" "$BUILD_DIR/PKGBUILD" 2>/dev/null | head -n1)"
  # Informational only: what it actually trusts is a fixed hash, not a
  # live signature.
  note "pinned sha256 (x86_64)" \
    "$(sed -n "s/^sha256sums_x86_64=(['\"]\\{0,1\\}\\([0-9a-f]*\\).*/\\1/p" \
      "$BUILD_DIR/PKGBUILD" 2>/dev/null | head -n1)"
}

# ===========================================================================
# Step 2 — build (this is where the pinned hash is actually checked)
# ===========================================================================

BUILT_PACKAGE=""

build_package() {
  info "2. Build"

  check "makepkg builds ${AUR_PACKAGE} (downloads and verifies the pinned SHA256)" \
    as_builder "cd '$BUILD_DIR' && makepkg --syncdeps --noconfirm --needed"

  BUILT_PACKAGE="$(find "$BUILD_DIR" -maxdepth 1 -name "${AUR_PACKAGE}-*.pkg.tar.*" | head -n1)"
  check "build produced a package" test -n "$BUILT_PACKAGE"
}

# ===========================================================================
# Step 3 — install
# ===========================================================================

install_cli() {
  info "3. Install"

  check_fails "package is not already installed" package_installed
  check "pacman installs the built package" pacman -U --noconfirm "$BUILT_PACKAGE"
  check "package is installed" package_installed
  note "installed version" "$(installed_version)"
}

# ===========================================================================
# Step 4 — run it
# ===========================================================================

run_cli() {
  info "4. Run it"
  check_binaries_and_run   # shared with test-install.sh — see common.sh
}

# ===========================================================================
# Wrong-key test — a corrupted pin must not build
# ===========================================================================

corrupted_pin_is_refused() {
  info "Wrong-key test: a corrupted pinned checksum must not build"

  if [ ! -d "$BUILD_DIR" ]; then
    note "wrong-key test skipped" "no PKGBUILD to corrupt"
    return 0
  fi

  local corrupt="$WORK/corrupt"
  rm -rf "$corrupt"
  cp -r "$BUILD_DIR" "$corrupt"
  sed -i "s/^\\(sha256sums_x86_64=(['\"]\\{0,1\\}\\)[0-9a-f]*/\\1$(printf '0%.0s' {1..64})/" \
    "$corrupt/PKGBUILD"
  chown -R "$BUILD_USER" "$corrupt"

  check_fails "makepkg refuses a package whose download does not match the pin" \
    as_builder "cd '$corrupt' && makepkg --syncdeps --noconfirm --needed"
}

# ===========================================================================

main() {
  : > "$JOTTA_RESULTS"

  step bootstrap

  if step fetch_pkgbuild && step build_package; then
    step install_cli && step run_cli
  else
    note "install and run skipped" "the build step did not produce a package"
  fi

  step corrupted_pin_is_refused

  finish
}

main "$@"

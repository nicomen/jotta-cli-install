# jotta-cli install & signing matrix

A GitHub Actions matrix that installs [`jotta-cli`](https://docs.jottacloud.com/en/collections/178064-installing-the-command-line-tool)
from the **public Jottacloud repositories**, exactly the way the documentation
tells users to, and checks that the signing chain actually holds end to end.

Nothing here needs credentials — no Jottacloud account, no secrets.

**The point of this repo**: catch it here, first, before a user hits it and
files a bug — a broken repo, a bad mirror, a package that won't install, a
daemon that won't start. That's what the grid's two columns are: **install**
(did `jotta-cli` actually install) and **execution** (does it actually run).
The wrong-key test (see "What it checks") is a different, secondary kind of
check — a security regression nobody following the real instructions would
ever stumble into — so it's deliberately kept out of those two columns and
shown only in the failing-checks list.

## Status

<!-- STATUS:BEGIN -->

[![install matrix](https://github.com/nicomen/jotta-cli-install/actions/workflows/install-matrix.yml/badge.svg)](https://github.com/nicomen/jotta-cli-install/actions/workflows/install-matrix.yml)

| Distro | amd64 | arm64 | armhf | i386 |
|---|:-:|:-:|:-:|:-:|
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 8 (UBI) | ❌/— | ❌/— | · | · |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 8 | ❌/— | ❌/— | · | · |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 11 (bullseye) | ❌/— | ❌/— | ❌/— | ❌/— |
| <img src="https://cdn.simpleicons.org/centos" width="16" height="16" valign="middle" alt=""> CentOS Stream 9 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 22.04 LTS | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 9 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 9 (UBI) | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/rockylinux" width="16" height="16" valign="middle" alt=""> Rocky Linux 9 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 12 (bookworm) | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 24.04 LTS | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/opensuse" width="16" height="16" valign="middle" alt=""> openSUSE Leap 15.6 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/fedora" width="16" height="16" valign="middle" alt=""> Fedora 40 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/centos" width="16" height="16" valign="middle" alt=""> CentOS Stream 10 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 10 (UBI) | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/rockylinux" width="16" height="16" valign="middle" alt=""> Rocky Linux 10 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 10 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/suse" width="16" height="16" valign="middle" alt=""> SLES 15 SP7 | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 13 (trixie) | ✅/✅ | ✅/✅ | ✅/✅ | ✅/✅ |
| <img src="https://cdn.simpleicons.org/fedora" width="16" height="16" valign="middle" alt=""> Fedora (latest) | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 26.04 LTS | ✅/✅ | ✅/✅ | · | · |
| <img src="https://cdn.simpleicons.org/opensuse" width="16" height="16" valign="middle" alt=""> openSUSE Tumbleweed | ❌/✅ | ❌/✅ | · | · |

Each cell is install/run. ✅ passed · ❌ failed · — not reached (an earlier phase failed) ·
⏳ not run in this tier · · not published for that architecture

**Failing checks**

| Failing check | Legs |
|---|---|
| fatal error | debian-11-amd64, debian-11-arm64, debian-11-armhf, debian-11-i386 |
| install from the superseded-key repository is refused | opensuse-tumbleweed-amd64, opensuse-tumbleweed-arm64 |
| nothing was installed by the refused attempt | opensuse-tumbleweed-amd64, opensuse-tumbleweed-arm64 |
| repository configured to trust only that key | almalinux-8-amd64, almalinux-8-arm64, registry.access.redhat.com-ubi8-ubi-latest-amd64, registry.access.redhat.com-ubi8-ubi-latest-arm64 |

<sub>2026-09-19 23:31 UTC · published version `0.17.176206` · signing key `DD0330E486A55840D37BDE77068CACA1BBF96E71` · [run](https://github.com/nicomen/jotta-cli-install/actions/runs/35476069863)</sub>

<!-- STATUS:END -->

Each cell that actually ran shows two icons, **install/run** — installing and
running are different failure modes worth telling apart at a glance. `—` means
the leg never reached that phase because an earlier one failed.

The wrong-key test (see below) is neither of those two things, so it's
excluded from both columns rather than folded into either — it's why
Tumbleweed can show a clean `✅/✅` here even though it has a real failure:
the install and the run both genuinely work, only the wrong-key rejection is
broken. Check the "Failing checks" table above for that.

The grid above is regenerated by the `summary` job on every push to `main` and
on the nightly cron, and committed back. `⏳` means the leg is a published
target but was not part of the tier that last ran; `·` means that distro has no
package for that architecture.

## What it checks

Per distro/arch leg (`scripts/test-install.sh`, run inside a container) the test
is just the four steps the documentation gives a user, with the signing that is
supposed to protect each one asserted as it goes:

| Step | What it does | What it asserts |
|---|---|---|
| **1. Add the repository** | fetch the key, write the apt/dnf/zypper entry | the key has the **pinned fingerprint** |
| **2. Update** | refresh the package lists | the metadata is **signed by that key** — verified independently, so a package manager that only warns cannot hide a bad signature |
| **3. Install** | `install jotta-cli`, signature checking left on | it installs, and the bytes on disk are the signed ones (`rpm --checksig`, or `.deb` SHA256 against the signed `Packages` index) |
| **4. Run it** | start `jottad`, talk to it with `jotta-cli` | the daemon answers, and `jotta-cli`, `jottad` and the package all report the same version |

Then a **wrong-key test**: the same four steps, pinned to the *superseded* key,
starting from a clean state (package removed, good repo and good key forgotten).
It must fail, and must leave nothing installed. Without it, the run above would
only prove that installing works — not that the signature is what made it work.

Once, on Arch Linux (`scripts/test-install-aur.sh`) — jotta maintains an
[official AUR package](https://aur.archlinux.org/packages/jotta-cli), a
fundamentally different trust model from the repositories above: there is no
live GPG check, `makepkg` instead refuses to build unless the download
matches a SHA256 **pinned inside the PKGBUILD itself**. The four steps become
fetch the PKGBUILD, build (where the pin is checked), install, run — plus a
wrong-key test that corrupts the pin and requires the build to fail.

Once per run, on the host (`scripts/check-keys.sh`):

- every published key path on **both** hosts (`repo.jotta.cloud`, `repo.jotta.us`)
  resolves to the fingerprint it is supposed to
- every suite's metadata (`debian`, `unstable`, `redhat`) verifies against the pinned key
- the two hosts serve **byte-identical** metadata
- the pinned key is not about to expire (default warning window: 90 days)
- every URL the docs tell users to paste still resolves

## Known state of the repositories

Established while writing this (2026-09-18):

| Thing | Value |
|---|---|
| Documented host | `https://repo.jotta.cloud` |
| Legacy host (still live, same content) | `https://repo.jotta.us` |
| Debian line | `deb [signed-by=/usr/share/keyrings/jotta.gpg] https://repo.jotta.cloud/debian debian main` |
| Debian suites | `debian`, `unstable` |
| Debian architectures | `amd64 arm64 armhf i386` |
| RPM baseurl | `https://repo.jotta.cloud/redhat` |
| RPM architectures | `x86_64 aarch64 armv7hl i386` |
| Latest published version | `0.17.176206` |

### Two keys are served, and only one of them is live

| URL path | Key | Status |
|---|---|---|
| `/jotta.gpg` | ed25519 `DD03 30E4 86A5 5840 D37B DE77 068C ACA1 BBF9 6E71`, created 2026-03-13 | **signs everything currently published** |
| `/public.gpg` | RSA4096 `E2CB EED2 DECB 21BF 686A B4B3 7DEF BCE9 947F 9F0F`, created 2017-10-23, expires 2030-10-08 | superseded — verifies nothing any more |

Both paths are served from both hosts. Anything still following older
instructions that fetch `/public.gpg` gets `NO_PUBKEY DD0330E4…` on
`apt-get update`. Check #3 above is written to keep that failure mode pinned
down rather than silently drifting.

Notes from actually running this:

- **ed25519 needs rpm >= 4.15.** AlmaLinux 8 (rpm 4.14.3) cannot even
  `rpm --import` the key — so the whole EL8 family (Alma 8, Rocky 8, RHEL 8,
  CentOS 8) cannot verify this repository. openSUSE Leap 15.6 passes despite
  also shipping 4.14.x, because SUSE backported the support. Both targets are
  in the matrix and both are expected to be red until that is addressed.
- **Debian 11 is not EOL — it's mid-transition, which is worse for testing.**
  Per [Debian's own LTS schedule](https://wiki.debian.org/LTS), free/public
  support (regular, then LTS) ran until 2026-08-31; after that it moves to
  Freexian's commercial Extended LTS (through 2031), on separate
  subscription-only infrastructure this test has no access to and a typical
  end user wouldn't either. The leg fails because the *public* mirrors this
  test actually uses are exactly what just lost coverage: `deb.debian.org`
  drops the release entirely (main moves to `archive.debian.org`), while
  `security.debian.org` keeps serving `bullseye-security`'s index but, as of
  writing, that index advertises a `gnupg2` update whose `.deb` 404s on
  `security.debian.org` itself — a real gap in Debian's own infrastructure at
  the moment of transition, not a sign the release has been dead for years.
- The ed25519 key currently carries **no expiry**, so the expiry check is a
  no-op until that changes.
- **`dnf5` exits 0 from `makecache` even when metadata signature verification
  fails**, printing only `>>> repomd.xml GPG signature verification error`. The
  negative test therefore asserts that the *install* is refused; asserting on
  the refresh would silently pass on Fedora.
- **Without a systemd user session, `jottad` listens on `127.0.0.1:14443`**, not
  on the unix socket it uses under logind. The smoke test waits for
  `jotta-cli version` to succeed rather than for a socket path to appear.
- **zypper on Tumbleweed does not refuse an unverifiable-signature install
  under `--non-interactive`.** Pointed at a repo whose real signature doesn't
  match the configured key, it prints "Continue? [y/n/...] (y)" and installs
  anyway — apt, dnf and yum all hard-abort in the same situation, and so does
  zypper on Leap 15.6. This is a genuine finding, not a test bug: the counter-
  check is deliberately left failing on Tumbleweed rather than worked around,
  because "install succeeded when it shouldn't have" is exactly the class of
  thing this repo exists to catch.

## Running it

### On GitHub

Pushes, pull requests and a daily 05:17 UTC cron all run the **all** tier —
`inputs.tier` only exists on a manual `workflow_dispatch` run, so every other
trigger falls back to it. `workflow_dispatch` lets you pick a narrower tier
instead, and point the run at another host or suite:

| Tier | Legs | What |
|---|---|---|
| `core` | 4 | Debian 12, Ubuntu 24.04, Fedora, Rocky 9 — amd64 only |
| `broad` | 40 | every distro × amd64 + arm64 |
| `all` (default) | 46 | broad, plus Debian armhf and i386 under QEMU |

The `keys` and `aur` jobs aren't part of the tier/matrix at all — they run on
every trigger regardless of which tier the matrix uses.

arm64 legs use GitHub's `ubuntu-24.04-arm` runners, which are free for public
repositories.

A warm leg takes about 40 seconds; a cold one is dominated by the container
image pull (`rockylinux:9` is 244 MB, `almalinux:9` 200 MB, `fedora` 190 MB) and
by the distro's own package metadata. In CI each leg has its own runner, so
wall-clock is roughly the slowest leg rather than the sum.

### Locally

Needs Docker or Podman. `CONTAINER_RUNTIME` picks one; it defaults to `docker`
to match the GitHub runners, and podman works rootless.

```sh
# the whole matrix, plus the grid at the end
scripts/run-all.sh                  # broad tier
scripts/run-all.sh core             # the four quick legs
JOBS=3 scripts/run-all.sh all       # three at a time, including emulated legs

CONTAINER_RUNTIME=podman scripts/run-all.sh core

# host-side key and metadata audit, no container at all
scripts/check-keys.sh

# one distro leg
IMAGE=debian:12 PLATFORM=linux/amd64 scripts/run-target.sh

# an emulated leg (needs binfmt handlers; run-all.sh skips these if absent)
IMAGE=debian:12 PLATFORM=linux/arm/v7 NEEDS_QEMU=1 scripts/run-target.sh

# render what came out
scripts/report.sh --grid     results   # distro x arch grid
scripts/report.sh --failures results   # failing checks, grouped by check
scripts/report.sh --all      results   # every check on every leg

# splice the grid into README.md between the STATUS markers
scripts/update-readme.sh results README.md
```

## Layout

```
.github/workflows/install-matrix.yml   plan -> install (matrix) -> summary
matrix.json                            the targets, one object per leg
scripts/common.sh                      repo facts, logging, check/record, gpg helpers
scripts/check-keys.sh                  host-side key + metadata audit
scripts/run-all.sh                     host-side: run the whole matrix locally
scripts/run-target.sh                  host-side: run one leg in a container
scripts/test-install.sh                in-container: install and verify
scripts/report.sh                      results.tsv -> Markdown (grid / failures / detail)
scripts/update-readme.sh               splice the grid into README.md
```

Every knob lives in one of two places: repository facts (hosts, key paths,
pinned fingerprint, suite, package name) at the top of `scripts/common.sh`, and
the target list in `matrix.json`.

### Adding a target

Add an object to `matrix.json`, placed in `released` order (oldest first) —
that's also the order the grid's rows and the Actions job list follow, and
it's the axis this whole repo cares about: whether something old still works
against a rotated key:

```json
{
  "id": "debian-14-amd64",
  "name": "Debian 14 / amd64",
  "distro": "Debian 14",
  "image": "debian:14",
  "family": "debian",
  "platform": "linux/amd64",
  "arch": "amd64",
  "runner": "ubuntu-24.04",
  "qemu": false,
  "tier": "broad",
  "released": "2027-06"
}
```

`released` is an approximate GA month (`"rolling"` for a rolling release like
Tumbleweed, which always sorts last). It's cosmetic — nothing enforces the
order — but keeping it means a glance at the grid answers "how far back does
this still work" without cross-referencing anything else.

`tier` is one of `core`, `broad`, `qemu`. Set `qemu: true` (and leave `runner`
as an amd64 runner) for any platform that needs binfmt emulation —
`scripts/run-target.sh` installs the handlers and the rest of the leg is
identical to a native one.

### Pointing at a different repository

```sh
JOTTA_HOST=https://repo.jotta.us \
JOTTA_DEB_SUITE=unstable \
JOTTA_EXPECTED_FPR=<fingerprint> \
  scripts/check-keys.sh
```

Any exported `JOTTA_*` variable is forwarded into the container by
`scripts/run-target.sh`, so the same overrides work for a full leg.

## When the signing key rotates

Update `JOTTA_EXPECTED_FPR` (and, if the old key stays published,
`JOTTA_LEGACY_FPR`) in `scripts/common.sh`. That is the only edit needed — the
pin is referenced from everywhere else.

# jotta-cli install & signing matrix

A GitHub Actions matrix that installs [`jotta-cli`](https://docs.jottacloud.com/en/collections/178064-installing-the-command-line-tool)
from the **public Jottacloud repositories**, exactly the way the documentation
tells users to, and checks that the signing chain actually holds end to end.

Nothing here needs credentials — no Jottacloud account, no secrets.

**The point of this repo**: catch it here, first, before a user hits it and
files a bug — a broken repo, a bad mirror, a package that won't install, a
daemon that won't start. Each cell in the grid is one leg: did the documented
install work, end to end, and does `jotta-cli` actually run afterward.

## Status

<!-- STATUS:BEGIN -->
| Distro | Released | EOL | amd64 | arm64 | i386 | armhf | amd64 | arm64 | i386 | armhf |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|  |  |  | **stable** |  |  |  | **unstable** |  |  |  |
| **RHEL family** |  |  |  |  |  |  |  |  |  |  |
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 8 (UBI) | 2019‑05‑07 | 2029‑05‑31 | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 8 | 2021‑03‑30 | 2029‑05‑31 | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="not published for this architecture">·</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/centos" width="16" height="16" valign="middle" alt=""> CentOS Stream 9 | 2021‑09‑15 | 2027‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 9 (UBI) | 2022‑05‑18 | 2032‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 9 | 2022‑05‑26 | 2032‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/rockylinux" width="16" height="16" valign="middle" alt=""> Rocky Linux 9 | 2022‑07‑14 | 2032‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/fedora" width="16" height="16" valign="middle" alt=""> Fedora 40 | 2024‑04‑23 | ~~2025‑05‑13~~ | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/centos" width="16" height="16" valign="middle" alt=""> CentOS Stream 10 | 2024‑12‑12 | 2030‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/redhat" width="16" height="16" valign="middle" alt=""> RHEL 10 (UBI) | 2025‑05‑20 | 2035‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/almalinux" width="16" height="16" valign="middle" alt=""> AlmaLinux 10 | 2025‑05‑27 | 2035‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/rockylinux" width="16" height="16" valign="middle" alt=""> Rocky Linux 10 | 2025‑06‑11 | 2035‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/fedora" width="16" height="16" valign="middle" alt=""> Fedora (latest) | 2026‑04‑28 | 2027‑05‑19 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| **Debian / Ubuntu** |  |  |  |  |  |  |  |  |  |  |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 11 (bullseye) | 2021‑08‑14 | ~~2026‑08‑31~~ | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> | <span title="failed">❌</span> |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 22.04 LTS | 2022‑04‑21 | 2027‑06‑01 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 12 (bookworm) | 2023‑06‑10 | 2028‑06‑30 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 24.04 LTS | 2024‑04‑25 | 2029‑05‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian 13 (trixie) | 2025‑08‑09 | 2030‑06‑30 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 26.04 LTS | 2026‑04‑23 | 2031‑05‑29 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> |
| <img src="https://cdn.simpleicons.org/debian" width="16" height="16" valign="middle" alt=""> Debian sid (unstable) | rolling | rolling | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/ubuntu" width="16" height="16" valign="middle" alt=""> Ubuntu 26.10 (development) | rolling | rolling | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="failed">❌</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="failed">❌</span> |
| **SUSE** |  |  |  |  |  |  |  |  |  |  |
| <img src="https://cdn.simpleicons.org/opensuse" width="16" height="16" valign="middle" alt=""> openSUSE Leap 15.6 | 2024‑06‑12 | ~~2026‑04‑30~~ | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/suse" width="16" height="16" valign="middle" alt=""> SLES 15 SP7 | 2025‑06‑17 | 2031‑07‑31 | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="not published for this architecture">·</span> | <span title="not published for this architecture">·</span> |
| <img src="https://cdn.simpleicons.org/opensuse" width="16" height="16" valign="middle" alt=""> openSUSE Tumbleweed | rolling | rolling | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> | <span title="passed">✅</span> |

stable/unstable are jotta's two package channels (see "What it checks"
for what unstable means). The bold row under the header names each
block -- GitHub's tables can't really span a header over several
columns, this is the closest approximation. ✅ passed · ❌ failed · ⏳ no
result yet (run in progress) · · not published for that architecture.
A ~~struck-through~~ EOL date means it's already past that date as of
today. Rows are grouped by family, oldest-release-first within each
group; GitHub renders this as a static table (no JS allowed in
READMEs), so there's no interactive re-sort.

**Failing checks**

| Failing check | Legs |
|---|---|
| fatal error | debian-11-amd64-unstable, debian-11-amd64, debian-11-arm64-unstable, debian-11-arm64, debian-11-armhf-unstable, debian-11-armhf, debian-11-i386-unstable, debian-11-i386, ubuntu-devel-armhf-unstable, u |
| repository configured to trust only that key | almalinux-8-amd64-unstable, almalinux-8-amd64, almalinux-8-arm64-unstable, almalinux-8-arm64, almalinux-8-i386-unstable, almalinux-8-i386, registry.access.redhat.com-ubi8-ubi-latest-amd64-unstable, re |

<sub>2026-09-26 10:00 UTC · published version `0.17.176206` · signing key `DD0330E486A55840D37BDE77068CACA1BBF96E71` · [run](https://github.com/nicomen/jotta-cli-install/actions/runs/36234021785)</sub>

<!-- STATUS:END -->

Each cell that actually ran shows two icons, **install/run** — installing and
running are different failure modes worth telling apart at a glance. `—` means
the leg never reached that phase because an earlier one failed.

The grid above is regenerated by the `summary` job on every push to `main` and
on the nightly cron, and committed back. `⏳` means the leg is a published
target but has no result yet (its job is still running or didn't finish);
`·` means that distro has no package for that architecture.

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

Once, on Arch Linux (`scripts/test-install-aur.sh`) — jotta maintains an
[official AUR package](https://aur.archlinux.org/packages/jotta-cli), a
fundamentally different trust model from the repositories above: there is no
live GPG check, `makepkg` instead refuses to build unless the download
matches a SHA256 **pinned inside the PKGBUILD itself**. The four steps become
fetch the PKGBUILD, build (where the pin is checked), install, run.

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
| RPM baseurl | `https://repo.jotta.cloud/redhat` (also `/redhat-unstable`) |
| RPM architectures | `x86_64 aarch64 armv7hl i386` |
| Latest published version | `0.17.176206` |

`armv7hl`/`i386` RPMs are published, but **no container image exists to test
them against**: Fedora 40+, Rocky 9+, AlmaLinux 8+, and CentOS Stream all
dropped 32-bit x86 and armv7 as supported architectures at the OS level (only
`amd64`/`arm64`/`ppc64le`/`s390x` images exist for any of them) — those RPMs
are presumably there for EL6/EL7-era systems, none of which are in this
matrix. Ubuntu dropped `i386` images the same way (22.04+ ships no `i386`
variant at all), so Ubuntu gets `armhf` coverage but not `i386`. `i386` and
`armhf` end up Debian-only not by choice, but because Debian is the only
family whose current releases still have images for both.

`unstable` is **not** an unstable *OS* — it's jotta's own pre-release build of
`jotta-cli` itself, decoupled from which distro runs it. Confirmed: its
`Packages`/`repomd.xml` list a different, unrelated version history from the
stable suite's (`0.17.176171…` vs `0.17.176206…`), and the RPM side has the
identical split at `/redhat-unstable`. Since an unstable build can carry new
packaging (scripts, dependencies, file layout) that behaves differently
across OS versions in ways the version number alone wouldn't reveal, every
distro/arch leg in the matrix has a `— jotta unstable channel` twin pointed
at that repo instead — doubles the matrix, but "does the new packaging work
on distro X" and "is distro X's own repo access still fine" are genuinely
different questions, and testing unstable on only one OS per family would
have quietly assumed they weren't. This is a different question from "does a
rolling *OS* work" (`Debian sid`, `openSUSE Tumbleweed`, `Ubuntu 26.10
(development)`), which installs jotta's normal stable channel on a rolling
distro instead.

`Ubuntu 26.10 (development)` is `ubuntu:devel` — Canonical's own nightly
build of whatever the next release is (codename `stonking` at the time of
writing; `/etc/os-release` in the image says `RELEASE_TYPE=development`),
not the eventual stable 26.10 that ships in October. It moves out from under
this the same way Debian sid or Tumbleweed's packages do; a red cell here
means "something in Ubuntu's own in-development packages currently breaks
this," not necessarily "the released 26.10 will be broken."

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

Every trigger — pushes, pull requests, the daily 05:17 UTC cron, and manual
`workflow_dispatch` — runs the whole matrix: all 48 targets in `matrix.json`.
`workflow_dispatch` only lets you point the run at a different host or suite,
not run a subset.

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
# the whole matrix, plus the grid at the end (skips any leg whose platform
# needs binfmt handlers this host doesn't have)
scripts/run-all.sh
JOBS=3 scripts/run-all.sh           # three legs at a time

CONTAINER_RUNTIME=podman scripts/run-all.sh

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
scripts/redraw.sh                      re-render the grid from the last CI run, no containers
```

### Previewing a grid change

Editing `scripts/report.sh`'s formatting (columns, grouping, the legend) and
want to see it rendered without waiting ~15-20 minutes for all 106 legs to
run again? `scripts/redraw.sh` pulls the small `results.tsv` artifacts from
the most recent completed run and renders *today's* `report.sh` against
*that* data — no containers, no images, just re-rendering:

```sh
scripts/redraw.sh              # print the grid to stdout
scripts/redraw.sh --write      # splice it into README.md, like CI does
scripts/redraw.sh --run 12345  # use a specific run instead of the latest
```

Needs `gh`, authenticated against this repo. The data is only as fresh as
whatever that run found — it won't reflect changes to the *tests themselves*,
only to how results are displayed.

Every knob lives in one of two places: repository facts (hosts, key paths,
pinned fingerprint, suite, package name) at the top of `scripts/common.sh`, and
the target list in `matrix.json`.

### Adding a target

Add an object to `matrix.json`:

```json
{
  "id": "debian-14-amd64",
  "name": "Debian 14 / amd64",
  "distro": "Debian 14",
  "image": "debian:14",
  "family": "debian",
  "group": "Debian / Ubuntu",
  "platform": "linux/amd64",
  "arch": "amd64",
  "runner": "ubuntu-24.04",
  "qemu": false,
  "released": "2027-06",
  "eol": "2032-06"
}
```

`group` is the grid's bold section divider ("Debian / Ubuntu", "RHEL family",
"SUSE" today) — sections are ordered by their earliest `released` date, and
rows within a section by their own `released`, oldest first (`"rolling"`
always sorts last within its section). `eol` gets struck through in the grid
once it's in the past.

Add `"live_eol": true` for a "moving tag" image like `fedora:latest`, whose
`released`/`eol` here are only a snapshot from whenever someone last checked
— Docker Hub silently repoints `latest` to the next release, and the
hardcoded date goes stale the moment that happens. With the flag set, the
grid instead uses the `SUPPORT_END` that leg's own `/etc/os-release` reported
at test time (`note_os_lifecycle` in `common.sh` records it automatically;
most distros don't carry `SUPPORT_END`, so this is a no-op for anything that
doesn't need it), falling back to the static `eol` here when no leg has
reported one yet.

Then add its unstable-channel twin — same fields, `id` suffixed `-unstable`,
`distro` suffixed ` — jotta unstable channel`, plus `"deb_suite": "unstable"`
(debian family) or `"rpm_path": "/redhat-unstable"` (rpm family). The grid
pairs a base row with its twin by exactly these suffixes, rendering them as
the stable/unstable columns of the same row rather than a second row — see
"What it checks" for why that twin exists at all.

Every target in the file runs on every trigger — there's no tier or subset to
opt into. Set `qemu: true` (and leave `runner` as an amd64 runner) for any
platform that needs binfmt emulation — `scripts/run-target.sh` installs the
handlers and the rest of the leg is identical to a native one.

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

# NZBGetVPN

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with VPN leak protection, OpenVPN/WireGuard, Privoxy, SOCKS support, and operational hooks.

Built on top of [`binhex/arch-int-vpn`](https://github.com/binhex/arch-int-vpn): the base image owns VPN/provider lifecycle, this repo owns NZBGet integration, helper scripts, and documentation.

[Thanks for the tip!](https://ko-fi.com/marc0janssen)

## Documentation

**Live documentation (search, navigation, dark mode): [https://marc0janssen.github.io/nzbgetvpn/](https://marc0janssen.github.io/nzbgetvpn/)**

That site is this repository rendered with **Material for MkDocs** on **GitHub Pages** — same content as here, but easier to browse: tabs for **Scripts**, **Guides** (CI, Compose examples), **Data directories**, and **Reference** (changelog, security). Prefer the website when you need to look something up; keep using this `README.md` when you need a single file in the repo or on Docker Hub.

Build and deploy: [`.github/workflows/docs.yml`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/.github/workflows/docs.yml) runs `mkdocs build --strict` on every relevant push and pull request; merges to `main` publish the site. Layout and tooling follow the same pattern as [restic-backup-helper](https://github.com/marc0janssen/restic-backup-helper) (`mkdocs.yml`, `docs/requirements.txt`, `docs/` with symlinks into existing markdown so relative links keep working).

### Preview on your machine

```sh
python3 -m venv .venv-docs
source .venv-docs/bin/activate   # or: source .venv-docs/bin/activate.fish
pip install -r docs/requirements.txt
mkdocs serve                      # http://127.0.0.1:8000
# mkdocs build --strict --site-dir site
```

On Windows, clone with symlink support if you build locally, for example `git clone -c core.symlinks=true …`. The `site/` output and `.venv-docs/` are gitignored.

### Enable GitHub Pages (once per repository)

If the live URL returns nothing or the **Docs** workflow fails verification, a repo admin must save Pages settings once: [Settings → Pages](https://github.com/marc0janssen/nzbgetvpn/settings/pages) → **Build and deployment** → **Source** → **GitHub Actions** → **Save**. Until then the GitHub API has no site record (`GET /repos/.../pages` returns **404**). Then push to `main` or run **Actions → Docs → Run workflow** on `main`. See GitHub’s guide: [Publishing with a custom GitHub Actions workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site#publishing-with-a-custom-github-actions-workflow). Private repositories and organization policies can block Pages.

A `DeprecationWarning: punycode` line in deploy logs comes from a Node dependency inside GitHub’s `deploy-pages` action; it is not the cause of deploy failures.

## CI Status

[![Quality Checks](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml)
[![Smoke Test](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml)
[![Security Scan](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/security-scan.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/security-scan.yml)
[![Drift Radar](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/drift-radar.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/drift-radar.yml)
[![Release Orchestration](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/release-orchestration.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/release-orchestration.yml)
[![Docs](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/docs.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/docs.yml)

## Table of Contents

- [Documentation](#documentation)
- [CI Status](#ci-status)
- [Versions](#versions)
- [Quick Start](#quick-start)
- [Compose](#compose)
- [Volumes](#volumes)
- [Core Environment](#core-environment)
- [Script Docs](#script-docs)
- [Provider Setup](#provider-setup)
- [Health, Self-Test, and Unhealthy Actions](#health-self-test-and-unhealthy-actions)
- [Build and Update](#build-and-update) (includes [Docker Hub builds](#docker-hub-builds), [local registry build](#local-registry-build))
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Versions

[NZBGet release information](https://github.com/nzbgetcom/nzbget/releases)

* NZBGetVPN image/codebase version: 5.6.9
* NZBGET Current stable version: 26.1
* NZBGET Current testing version: 26.2-testing-20260508
* Base image stable tag: binhex/arch-int-vpn:2026050402
* Base image testing tag: binhex/arch-int-vpn:2026050402

The NZBGetVPN image/codebase version is stored in `VERSION`.

## Quick Start

Default NZBGet login is `nzbget` / `tegbzn6789`. Change this immediately after first start.

OpenVPN:

```sh
docker run -d \
  --name=nzbgetvpn \
  --cap-add=NET_ADMIN \
  --restart unless-stopped \
  -p 6789:6789 \
  -p 8118:8118 \
  -v /path/to/config:/config \
  -v /path/to/data:/data \
  -v /etc/localtime:/etc/localtime:ro \
  -e VPN_ENABLED=yes \
  -e VPN_CLIENT=openvpn \
  -e VPN_PROV=custom \
  -e LAN_NETWORK=192.168.1.0/24 \
  -e NAME_SERVERS=1.1.1.1,1.0.0.1 \
  -e ENABLE_PRIVOXY=yes \
  -e STRICT_PORT_FORWARD=no \
  -e UMASK=000 \
  -e PUID=1000 \
  -e PGID=1000 \
  marc0janssen/nzbgetvpn:stable
```

WireGuard:

```sh
docker run -d \
  --name=nzbgetvpn \
  --privileged=true \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  -p 6789:6789 \
  -p 8118:8118 \
  -v /path/to/config:/config \
  -v /path/to/data:/data \
  -v /etc/localtime:/etc/localtime:ro \
  -e VPN_ENABLED=yes \
  -e VPN_CLIENT=wireguard \
  -e VPN_PROV=custom \
  -e LAN_NETWORK=192.168.1.0/24 \
  -e NAME_SERVERS=1.1.1.1,1.0.0.1 \
  -e ENABLE_PRIVOXY=yes \
  -e STRICT_PORT_FORWARD=no \
  -e UMASK=000 \
  -e PUID=1000 \
  -e PGID=1000 \
  marc0janssen/nzbgetvpn:stable
```

## Compose

Ready-to-edit examples live in [`examples/`](examples/README.md).

## Volumes

| Path | Required | Description |
| --- | --- | --- |
| `/config` | Yes | Persistent config, OpenVPN profiles and WireGuard profiles. |
| `/data` | Yes | Downloads and optional scripts/state. |
| `/etc/localtime:ro` | Recommended | Keeps container time aligned with host time. |

## Core Environment

| Variable | Required | Example | Purpose |
| --- | --- | --- | --- |
| `VPN_ENABLED` | Usually | `yes` | Enable/disable VPN behavior. |
| `VPN_CLIENT` | If VPN enabled | `openvpn`, `wireguard` | Select VPN implementation. |
| `VPN_PROV` | If VPN enabled | `custom` | Provider key for base image handling. |
| `LAN_NETWORK` | If VPN enabled | `192.168.1.0/24` | Allowed LAN CIDR(s) for local services. |
| `NAME_SERVERS` | Recommended | `1.1.1.1,1.0.0.1` | Resolver list inside container. |
| `ENABLE_PRIVOXY` | No | `yes` | Enables Privoxy on `8118/tcp`. |
| `PUID` / `PGID` | No | `1000` | Runtime ownership. |
| `UMASK` | No | `000` | File creation mask. |
| `BUNDLED_SYNC_POLICY` | No | `smart`, `force`, `preserve` | Controls startup sync behavior for bundled `/data` templates (default `smart`; docs still sync in smart mode). |

Boolean-style toggles across this project accept `yes`/`no`, `true`/`false`, and `1`/`0`.

## Script Docs

Script details are split into smaller files to reduce maintenance overhead and merge conflicts. The same pages are available on **[the documentation website](https://marc0janssen.github.io/nzbgetvpn/)** under **Scripts**.

- Index: [`data/scripts/README.md`](data/scripts/README.md)
- Per-script docs under [`data/scripts/docs/`](data/scripts/README.md#per-script-docs)
- Bundled script docs are also synced into the container at `/data/scripts/docs/`.
- Add `nzbgetvpn: preserve-local` in managed runtime script files (for example `/data/scripts/lib.sh`) to keep local custom edits when `BUNDLED_SYNC_POLICY=smart`; README/docs files ignore this marker and still update.
- For quick local diagnostics, run `/data/scripts/container/doctor.sh` inside the container.
- To force-restore managed bundled templates and then run diagnostics, use `/data/scripts/container/doctor.sh --heal` (creates backups under `/data/backups/doctor-heal-<timestamp>/`).
- For host-side execution via a running container, use `./data/scripts/host/run-container-helper.sh`.

## Provider Setup

### OpenVPN

1. Start once so `/config/openvpn/` is created.
2. Stop container.
3. Put one `.ovpn` and referenced files in `/config/openvpn/`.
4. Start container.

### WireGuard

1. Start once so `/config/wireguard/` is created.
2. Stop container.
3. Put one `.conf` in `/config/wireguard/`.
4. Start container.

## Health, Self-Test, and Unhealthy Actions

- Docker healthcheck runs `/root/healthcheck.sh`.
- Internal self-test is controlled by `VPN_SELFTEST_ENABLED`.
- Unhealthy behavior is controlled by `VPN_UNHEALTHY_*`.
- Dedicated notifications use `NOTIFY_SELFTEST_STATE_SCRIPT` and `NOTIFY_UNHEALTHY_SCRIPT`.

## Build and Update

Use `build.sh`, `build-testing.sh`, `build-testing-local.sh`, and scripts in `scripts/`.

### Docker Hub builds

**Scripts:** `build.sh` (stable image, `Dockerfile`) and `build-testing.sh` (testing image, `Dockerfile-testing`). Both push to Docker Hub via `docker buildx build ... --push` and run `docker pushrm` for `README-containers.md`.

**Optional env files (gitignored, not pushed to GitHub)**

| File | Template | Used by |
| --- | --- | --- |
| `build.env` | `build.env.example` | `build.sh` |
| `build-testing.env` | `build-testing.env.example` | `build-testing.sh` |

Copy and edit: `cp build.env.example build.env` (same idea for testing).

Place the file in the **repository root**, next to the matching script. Format: POSIX shell assignments (`KEY=value`), `#` comments.

| Variable | Default when unset | Purpose |
| --- | --- | --- |
| `DOCKER_IMAGE_REPO` | `marc0janssen/nzbgetvpn` | Docker Hub repository (`namespace/name`, **no** tag). Used for all `-t` arguments and for `docker pushrm`. |
| `BUILD_PLATFORM` | `linux/amd64,linux/arm64` | Passed to `docker buildx build --platform`. |

**Precedence:** built-in defaults, then assignments in the env file if present, then **`DOCKER_IMAGE_REPO` / `BUILD_PLATFORM` already exported** in your shell (exports win over the file), then **`--docker-repo`** and **`--platform`** on the command line (strongest).

```sh
./build.sh --docker-repo otheruser/nzbgetvpn --platform linux/amd64
./build-testing.sh --docker-repo otheruser/nzbgetvpn
```

### Local registry build

Script: **`build-testing-local.sh`**. Use this for pushing **testing** images to **your own** Docker registry (home lab, LAN, or VPN), instead of Docker Hub. Behaviour matches `build-testing.sh` for NZBGet bumps (`newest`, `--sha256`, `--accept-downloaded-sha256`) and base image updates (`--base`), but the build uses `Dockerfile-testing` and ends with:

`sudo docker buildx build ... --push`

You need a working `buildx` builder, permission for `sudo docker`, and a registry that accepts pushes (login with `docker login` where required).

**Tags pushed to your registry** (repository = value of `LOCAL_REPO`, without tag):

| Tag | Meaning |
| --- | --- |
| `<NZBGET_VERSION>` | Taken from `Dockerfile-testing` (`ENV NZBGET_VERSION`), for example the testing train string. |
| `<NZBGET_VERSION>-image-v<semver>` | Same NZBGet version plus codebase semver from `VERSION` at repo root. |
| `testing` | Convenience rolling tag for the latest push from this script. |

There is no `docker pushrm` step; Docker Hub README sync is only for `build-testing.sh` / `build.sh`.

**Optional config file `build-testing-local.env`**

- **Git:** `build-testing-local.env` is listed in `.gitignore` so your registry hostname stays local and is not pushed to GitHub. The repository ships **`build-testing-local.env.example`** as a template; copy it and edit:
  `cp build-testing-local.env.example build-testing-local.env`
- **Location:** repository root, next to `build-testing-local.sh` (the script loads `build-testing-local.env` from that directory only).
- **Format:** POSIX shell assignments, one variable per line; lines starting with `#` are comments. No `export` keyword needed.
- **If the file is missing:** the script still runs; built-in defaults apply, and you can pass **`--repo`** / **`--platform`** anytime.

| Variable | Default when unset | Purpose |
| --- | --- | --- |
| `LOCAL_REPO` | `192.168.1.1:5000/nzbgetvpn` | Image repository on your registry: `host:port/path/name` with **no** image tag. |
| `LOCAL_PLATFORM` | `linux/amd64` | Value passed to `docker buildx build --platform` (comma-separated for multi-arch). |

**Precedence** (each step overrides the previous):

1. Built-in defaults in the script.
2. Assignments in `build-testing-local.env`, **if that file exists**.
3. **`LOCAL_REPO` / `LOCAL_PLATFORM` already set in the environment** when you start the script (exported values are **not** overwritten by the file, so your shell can override values from `build-testing-local.env`).
4. **`--repo`** and **`--platform`** on the command line (highest priority).

**Examples**

```sh
./build-testing-local.sh
./build-testing-local.sh --repo 192.168.178.200:5050/nzbgetvpn
./build-testing-local.sh newest --accept-downloaded-sha256 --platform linux/amd64,linux/arm64
export LOCAL_REPO=192.168.178.200:5050/nzbgetvpn
./build-testing-local.sh
```

Use `./build-testing-local.sh --help` for the full flag list.

CI quality checks (run locally and in GitHub Actions):

- Workflow: `.github/workflows/quality-checks.yml`
- Trigger: `push` and `pull_request`
- Scope:
  - unresolved merge conflict marker scan (`<<<<<<<`, `=======`, `>>>>>>>`)
  - Docker Hub README size guard (`README-containers.md` must stay under `25000` bytes)
  - shell syntax validation (`sh -n` / `bash -n` based on shebang)
  - `shellcheck` for static shell linting
  - `shfmt --diff` for formatting drift detection
  - rotate-defaults docs drift check (`./scripts/sync-rotate-defaults-doc.sh check`)
  - AGENTS.md validation checklist commands
  - optional conventional commit lint (enable with `CI_CONVENTIONAL_COMMIT_LINT=true`)

```sh
./scripts/ci-quality-checks.sh
```

Temporary shellcheck baseline is enabled by default for known legacy findings.
Run strict mode locally (no excludes) with:

```sh
SHELLCHECK_EXCLUDES= ./scripts/ci-quality-checks.sh
```

Optional conventional commit lint (for changelog/version flow consistency):

```sh
CI_CONVENTIONAL_COMMIT_LINT=true CI_CONVENTIONAL_COMMIT_RANGE=origin/develop..HEAD ./scripts/ci-quality-checks.sh
```

Runtime smoke test (run locally and in GitHub Actions):

- Workflow: `.github/workflows/smoke-test.yml`
- Trigger: `push` and `pull_request`
- Scope:
  - container boot and running-state validation
  - NZBGet `6789/tcp` and Privoxy `8118/tcp` reachability
  - healthcheck and direct self-test execution success

```sh
./scripts/ci-smoke-test.sh
```

Full smoke-test documentation: [`ci/README.md`](ci/README.md)
On Apple Silicon or other non-amd64 hosts, use `SMOKE_PLATFORM=linux/amd64`.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `LAN_NETWORK is not set` | Set valid CIDR like `192.168.1.0/24`. |
| `VPN_REMOTE_PORT is not set` | Verify provider profile and parsed endpoint values. |
| `VPN_CRON_SCHEDULE` doesn't run | Use 5-field cron and executable script path. |
| Container exits and stays down | Add restart policy (`unless-stopped`). |

## Security

See [`SECURITY.md`](SECURITY.md).  
Do not commit secrets, VPN profiles, keys, tokens, or `.env` files.

# NZBGetVPN

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with VPN leak protection, OpenVPN/WireGuard, Privoxy, SOCKS support, and operational hooks.

Built on top of [`binhex/arch-int-vpn`](https://github.com/binhex/arch-int-vpn): the base image owns VPN/provider lifecycle, this repo owns NZBGet integration, helper scripts, and documentation.

[Thanks for the tip!](https://ko-fi.com/marc0janssen)

## CI Status

[![Quality Checks](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml)
[![Smoke Test](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml)
[![Security Scan](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/security-scan.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/security-scan.yml)
[![Drift Radar](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/drift-radar.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/drift-radar.yml)
[![Release Orchestration](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/release-orchestration.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/release-orchestration.yml)

## Table of Contents

- [CI Status](#ci-status)
- [Versions](#versions)
- [Quick Start](#quick-start)
- [Compose](#compose)
- [Volumes](#volumes)
- [Core Environment](#core-environment)
- [Script Docs](#script-docs)
- [Provider Setup](#provider-setup)
- [Health, Self-Test, and Unhealthy Actions](#health-self-test-and-unhealthy-actions)
- [Build and Update](#build-and-update)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Versions

[NZBGet release information](https://github.com/nzbgetcom/nzbget/releases)

* NZBGetVPN image/codebase version: 5.5.3
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

Ready-to-edit examples live in [`examples/`](examples/).

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

Script details are split into smaller files to reduce maintenance overhead and merge conflicts.

- Index: [`data/scripts/README.md`](data/scripts/README.md)
- Per-script docs under [`data/scripts/docs/`](data/scripts/docs/)
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

Use `build.sh`, `build-testing.sh`, and scripts in `scripts/`.

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

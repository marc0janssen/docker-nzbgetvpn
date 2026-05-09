# NZBGetVPN

[![Quality Checks](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/quality-checks.yml)
[![Smoke Test](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml/badge.svg?branch=develop)](https://github.com/marc0janssen/nzbgetvpn/actions/workflows/smoke-test.yml)

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with OpenVPN/WireGuard, Privoxy, SOCKS support and VPN leak protection.

Built on top of [`binhex/arch-int-vpn`](https://github.com/binhex/arch-int-vpn):

- base image handles VPN/provider lifecycle
- this repository adds NZBGet integration, validation and helper workflows

## Versions

* NZBGetVPN image/codebase version: 5.3.8
* NZBGET Current stable version: 26.1
* NZBGET Current testing version: 26.2-testing-20260508
* Base image stable tag: binhex/arch-int-vpn:2026050402
* Base image testing tag: binhex/arch-int-vpn:2026050402

## Tags

| Tag | Description |
| --- | --- |
| `stable` | Stable NZBGet release |
| `testing` | Testing NZBGet release |
| `<version>` | Versioned app tag, e.g. `26.1` |
| `<nzbget-version>-image-v<version>` | Combined app/codebase tag, e.g. `26.1-image-v4.24.7` |

## Quick Start

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

WireGuard (replace capabilities):

```yaml
privileged: true
sysctls:
  net.ipv4.conf.all.src_valid_mark: "1"
```

Default NZBGet login: `nzbget` / `tegbzn6789` (change after first start).

## Core Volumes

| Path | Description |
| --- | --- |
| `/config` | Persistent app/VPN config |
| `/data` | Downloads, scripts, state |
| `/etc/localtime:ro` | Optional timezone alignment |

Bundled scripts are managed in `/data/scripts`.
Bundled script docs are synced to `/data/scripts/docs`.

## Core Variables

| Variable | Example | Description |
| --- | --- | --- |
| `VPN_ENABLED` | `yes` | Enable VPN handling |
| `VPN_CLIENT` | `openvpn`, `wireguard` | Select client |
| `VPN_PROV` | `custom` | Provider key |
| `LAN_NETWORK` | `192.168.1.0/24` | Allowed LAN CIDR(s) |
| `NAME_SERVERS` | `1.1.1.1,1.0.0.1` | DNS list |
| `ENABLE_PRIVOXY` | `yes` | Privoxy on `8118/tcp` |
| `PUID` / `PGID` | `1000` | File ownership |
| `UMASK` | `000` | File creation mask |
| `BUNDLED_SYNC_POLICY` | `smart`, `force`, `preserve` | Startup sync policy for bundled `/data` templates (default `smart`; docs still sync in smart mode) |

Preserve marker behavior for managed bundled files:
- Add `nzbgetvpn: preserve-local` inside managed runtime script files (for example `/data/scripts/lib.sh`) to keep local edits when `BUNDLED_SYNC_POLICY=smart`.
- README/docs templates ignore this marker and continue syncing in `smart` mode.
- Startup logs will warn when files are preserved, because this can cause template drift and break behavior after image upgrades.

## Helper Script Documentation

- Script index: [`data/scripts/README.md`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/data/scripts/README.md)
- Per-script docs: [`data/scripts/docs/`](https://github.com/marc0janssen/nzbgetvpn/tree/develop/data/scripts/docs)
- Quick diagnostics helper: run `/data/scripts/container/doctor.sh` inside the container.
- Repair managed bundled templates and run diagnostics with `/data/scripts/container/doctor.sh --heal` (creates backups under `/data/backups/doctor-heal-<timestamp>/`).
- Host wrapper for running bundled scripts via `docker exec`: `./data/scripts/host/run-container-helper.sh`.

## Full Documentation

For complete environment matrix, self-test/unhealthy logic, provider setup, troubleshooting, and build/update workflow:

- [`README.md`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/README.md)
- Runtime smoke-test helper: `./scripts/ci-smoke-test.sh`
- Runtime smoke-test docs: [`ci/README.md`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/ci/README.md)
- For Apple Silicon/non-amd64 hosts, run smoke tests with `SMOKE_PLATFORM=linux/amd64`.
- Shell quality checks helper: `./scripts/ci-quality-checks.sh`
- GitHub Actions quality checks workflow: [`quality-checks.yml`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/.github/workflows/quality-checks.yml) (`push` + `pull_request`, conflict-marker scan + `README-containers.md` `<25000` bytes guard + syntax + `shellcheck` + `shfmt --diff` + AGENTS.md validation checklist).
- Rotate defaults docs are generated from shared runtime defaults with `./scripts/sync-rotate-defaults-doc.sh` and validated in quality checks.
- Quality checks use a temporary shellcheck baseline for legacy findings; run strict locally with `SHELLCHECK_EXCLUDES= ./scripts/ci-quality-checks.sh`.
- Optional conventional commit lint can be enabled with `CI_CONVENTIONAL_COMMIT_LINT=true` (workflow reads repo variable `CI_CONVENTIONAL_COMMIT_LINT`).
- GitHub Actions smoke-test workflow: [`smoke-test.yml`](https://github.com/marc0janssen/nzbgetvpn/blob/develop/.github/workflows/smoke-test.yml) (`push` + `pull_request`, runtime startup/reachability/self-test checks).

## Security

Do not expose credentials, tokens, VPN profiles, private keys, or `.env` files in public issues.

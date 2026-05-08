# NZBGetVPN Helper Scripts

Bundled scripts in this directory are managed by the image and copied to `/data/scripts` at container startup.

Use environment variables first. If you need custom logic, copy to a new filename and reference that copy from schedules/hooks.

## Table of Contents

- [Overview](#overview)
- [Source Layout](#source-layout)
- [Execution Context](#execution-context)
- [Usage Patterns](#usage-patterns)
- [Per-Script Docs](#per-script-docs)
- [Permissions](#permissions)

## Overview

| Script | Purpose | Run Context |
| --- | --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Fetch NordVPN WireGuard configs and install one active config. | Container-only |
| `select_random_wireguard_config.sh` | Pick random WireGuard profile from source directory. | Container-only |
| `select_random_openvpn_config.sh` | Pick random OpenVPN profile from source directory. | Container-only |
| `rotate_on_poor_speed.sh` | Rotate profile after repeated poor speed/latency checks. | Container-only |
| `lib.sh` | Shared shell helpers used by runtime and bundled scripts. | Internal library (not standalone) |
| `benchmark_endpoints.sh` | Benchmark endpoints and report best candidate. | Host-or-container |
| `backup_config.sh` | Create timestamped backups of config data. | Host-or-container |
| `log_sanitizer.sh` | Redact tokens/IP/paths before sharing logs. | Host-or-container |
| `upgrade_check.sh` | Compare local/remote versions before upgrade. | Host-or-container |
| `doctor.sh` | Run quick local diagnostics for config/runtime readiness. | Container-first (host possible with overrides) |
| `run-container-helper.sh` | Host wrapper to run `/data/scripts/*.sh` inside a running container. | Host-only |
| `notify_discord.sh` | Notification helper for Discord. | Host-or-container |
| `notify_telegram.sh` | Notification helper for Telegram. | Host-or-container |
| `notify_pushover.sh` | Notification helper for Pushover. | Host-or-container |

## Source Layout

Script sources are organized by category
- `data/scripts/container/` for container-focused helpers
- `data/scripts/shared/` for host-or-container helpers
- `data/scripts/notify/` for notification helpers
- `data/scripts/host/` for host-only wrappers
- `data/scripts/lib.sh` shared helper library

At image build/startup, bundled helpers are installed under category paths in `/data/scripts/{container,shared,notify,host}/`. Legacy flat `/data/scripts/<name>.sh` bundled copies are removed automatically.

## Execution Context

- **Container-only**: relies on container runtime behavior and standard container paths like `/config`, `/data`, VPN env vars, or scheduler hooks (`VPN_CRON_*`, `VPN_UNHEALTHY_*`).
- **Host-or-container**: can run from host or container when path/env inputs are valid.
- **Container-first (host possible with overrides)**: optimized for in-container checks, but can run on host for dry-runs when overriding path/environment variables.
- **Host-only**: intended to run on the Docker host, not inside the container.
- **Internal library**: sourced by other scripts, not intended as direct executable entrypoint.

## Usage Patterns

Manual:

```sh
docker exec -it nzbgetvpn /bin/bash
/data/scripts/shared/backup_config.sh
```

Host helper (runs bundled scripts inside a running container):

```sh
./data/scripts/host/run-container-helper.sh --container nzbgetvpn doctor.sh
```

Host helper from bind-mounted `/data`:

```sh
/path/to/data/scripts/host/run-container-helper.sh --container nzbgetvpn doctor.sh
```

Scheduled (`VPN_CRON_*`):

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/container/select_random_wireguard_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

Unhealthy action (`VPN_UNHEALTHY_*`):

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/container/get_wireguard_configs_nordvpn.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=300
```

Notification hooks:

```text
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify/notify_discord.sh
NOTIFY_UNHEALTHY_SCRIPT=/data/scripts/notify/notify_discord.sh
```

## Per-Script Docs

- `rotate_on_poor_speed` defaults are centralized in `data/scripts/lib.sh` and rendered into docs via `./scripts/sync-rotate-defaults-doc.sh`.
- [`docs/get_wireguard_configs_nordvpn.md`](docs/get_wireguard_configs_nordvpn.md)
- [`docs/select_random_wireguard_config.md`](docs/select_random_wireguard_config.md)
- [`docs/select_random_openvpn_config.md`](docs/select_random_openvpn_config.md)
- [`docs/rotate_on_poor_speed.md`](docs/rotate_on_poor_speed.md)
- [`docs/benchmark_endpoints.md`](docs/benchmark_endpoints.md)
- [`docs/backup_config.md`](docs/backup_config.md)
- [`docs/log_sanitizer.md`](docs/log_sanitizer.md)
- [`docs/upgrade_check.md`](docs/upgrade_check.md)
- [`docs/doctor.md`](docs/doctor.md)
- [`docs/notification_scripts.md`](docs/notification_scripts.md)

## Permissions

Make sure custom scripts are executable:

```sh
chmod +x /data/scripts/my-script.sh
```

# NZBGetVPN Helper Scripts

Bundled scripts in this directory are managed by the image and copied to `/data/scripts` at container startup.

Use environment variables first. If you need custom logic, copy to a new filename and reference that copy from schedules/hooks.

## Table of Contents

- [Overview](#overview)
- [Usage Patterns](#usage-patterns)
- [Per-Script Docs](#per-script-docs)
- [Permissions](#permissions)

## Overview

| Script | Purpose |
| --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Fetch NordVPN WireGuard configs and install one active config. |
| `select_random_wireguard_config.sh` | Pick random WireGuard profile from source directory. |
| `select_random_openvpn_config.sh` | Pick random OpenVPN profile from source directory. |
| `rotate_on_poor_speed.sh` | Rotate profile after repeated poor speed/latency checks. |
| `benchmark_endpoints.sh` | Benchmark endpoints and report best candidate. |
| `backup_config.sh` | Create timestamped backups of config data. |
| `log_sanitizer.sh` | Redact tokens/IP/paths before sharing logs. |
| `upgrade_check.sh` | Compare local/remote versions before upgrade. |
| `notify_discord.sh` | Notification helper for Discord. |
| `notify_telegram.sh` | Notification helper for Telegram. |
| `notify_pushover.sh` | Notification helper for Pushover. |

## Usage Patterns

Manual:

```sh
docker exec -it nzbgetvpn /bin/bash
/data/scripts/backup_config.sh
```

Scheduled (`VPN_CRON_*`):

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_wireguard_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

Unhealthy action (`VPN_UNHEALTHY_*`):

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=300
```

Notification hooks:

```text
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify_discord.sh
NOTIFY_UNHEALTHY_SCRIPT=/data/scripts/notify_discord.sh
```

## Per-Script Docs

- [`docs/get_wireguard_configs_nordvpn.md`](docs/get_wireguard_configs_nordvpn.md)
- [`docs/select_random_wireguard_config.md`](docs/select_random_wireguard_config.md)
- [`docs/select_random_openvpn_config.md`](docs/select_random_openvpn_config.md)
- [`docs/rotate_on_poor_speed.md`](docs/rotate_on_poor_speed.md)
- [`docs/benchmark_endpoints.md`](docs/benchmark_endpoints.md)
- [`docs/backup_config.md`](docs/backup_config.md)
- [`docs/log_sanitizer.md`](docs/log_sanitizer.md)
- [`docs/upgrade_check.md`](docs/upgrade_check.md)
- [`docs/notification_scripts.md`](docs/notification_scripts.md)

## Permissions

Make sure custom scripts are executable:

```sh
chmod +x /data/scripts/my-script.sh
```

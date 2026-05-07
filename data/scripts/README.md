# NZBGetVPN Helper Scripts

This directory contains bundled helper scripts that can run:

- manually
- from `VPN_CRON_SCRIPT`
- from `VPN_UNHEALTHY_SCRIPT`
- from notification hooks (`NOTIFY_SELFTEST_STATE_SCRIPT` / `NOTIFY_UNHEALTHY_SCRIPT`)

Bundled scripts are managed by the image. On container start, they are installed or updated from image templates. Keep your own custom scripts under a different filename to avoid overwrite.

## Bundled Scripts Overview

| Script | Purpose |
| --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Fetch NordVPN WireGuard recommendations and install one active WireGuard config. |
| `select_random_wireguard_config.sh` | Pick a random `*.conf` from `/data/wireguard-configs` and install it in `/config/wireguard`. |
| `select_random_openvpn_config.sh` | Pick a random `*.ovpn` from `/data/openvpn-configs` and install it in `/config/openvpn`. |
| `rotate_on_poor_speed.sh` | Trigger profile rotation when measured speed/latency stays below thresholds for a configurable streak. |
| `benchmark_endpoints.sh` | Benchmark multiple endpoints (latency + throughput), rank them, and report the best endpoint. |
| `backup_config.sh` | Create timestamped archives of `/config` to `/data/backups` (or custom target). |
| `log_sanitizer.sh` | Redact tokens/secrets, IP addresses, and absolute paths from logs before sharing. |
| `upgrade_check.sh` | Show whether a newer image/codebase version is available and print relevant changelog impact before updating. |
| `notify_discord.sh` | Send a state/unhealthy notification to a Discord webhook. |
| `notify_telegram.sh` | Send a state/unhealthy notification through the Telegram Bot API. |
| `notify_pushover.sh` | Send a state/unhealthy notification through Pushover. |

## Customization And Support Policy

Use bundled script files as managed templates. In most setups you should configure behavior via environment variables, not by editing the script files directly.

Recommended approach:

1. Start with bundled defaults.
2. Tune via documented environment variables.
3. If you need custom logic, copy to a new filename (for example `/data/scripts/my-rotate.sh`) and point scheduler/hooks to that file.

Support expectation:

- Supported and stable: changing documented env vars.
- Advanced/user-owned: editing bundled script contents directly.
- Safe customization path: clone to a different filename so image updates can still refresh bundled templates.

Quick guidance per script:

| Script | Typical customization need | Recommendation |
| --- | --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Sometimes | Usually env vars; copy script only for provider-specific logic changes. |
| `select_random_wireguard_config.sh` | Sometimes | Usually env vars; copy script for custom selection policies. |
| `select_random_openvpn_config.sh` | Sometimes | Usually env vars; copy script for custom selection policies. |
| `rotate_on_poor_speed.sh` | Rare | Tune thresholds/endpoints/weights via env vars; copy only for custom scoring logic. |
| `benchmark_endpoints.sh` | Rare | Tune endpoints/attempts/timeouts via env vars; copy only for custom report logic. |
| `backup_config.sh` | Rare | Tune source/target/retention env vars. |
| `log_sanitizer.sh` | Rare | Usually run as-is. Copy only if custom redaction rules are required. |
| `upgrade_check.sh` | Rare | Tune repo/branch/channel env vars. |
| `notify_discord.sh` | Rare | Configure webhook/env vars. Copy only for custom payload formatting. |
| `notify_telegram.sh` | Rare | Configure bot token/chat env vars. Copy only for custom payload formatting. |
| `notify_pushover.sh` | Rare | Configure app/user env vars. Copy only for custom payload formatting. |

## General Usage Patterns

### 1) Run manually (inside container)

```text
docker exec -it nzbgetvpn /bin/bash
/data/scripts/backup_config.sh
```

### 2) Run on schedule (`VPN_CRON_*`)

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_wireguard_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

### 3) Run when VPN is unhealthy (`VPN_UNHEALTHY_*`)

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=300
```

### 4) Run as notification hook

```text
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify_discord.sh
NOTIFY_SELFTEST_STATE_TIMEOUT=30
```

## Script Examples

## `get_wireguard_configs_nordvpn.sh`

Fetches NordVPN recommendations, downloads config(s), installs one active WireGuard profile into `/config/wireguard`.

Required:

```text
NORDVPN_ACCESS_TOKEN=your-token
```

Create token in Nord Account:

1. Log in to `https://my.nordaccount.com/`.
2. Open `NordVPN`.
3. Go to `Advanced settings`.
4. Click `Get access token`.
5. Verify email.
6. Generate token.
7. Copy token immediately.

Manual run:

```text
/data/scripts/get_wireguard_configs_nordvpn.sh
```

Run every 6 hours:

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_CRON_SCRIPT_TIMEOUT=300
NORDVPN_ACCESS_TOKEN=your-token
```

Run when unhealthy:

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=300
NORDVPN_ACCESS_TOKEN=your-token
```

## `select_random_wireguard_config.sh`

Selects a random `.conf` from `/data/wireguard-configs` and installs it as active config.

Prepare source directory:

```text
mkdir -p /data/wireguard-configs
# copy your *.conf files into /data/wireguard-configs
```

Manual run:

```text
/data/scripts/select_random_wireguard_config.sh
```

Scheduled rotation:

```text
VPN_CRON_SCHEDULE=0 */12 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_wireguard_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

## `select_random_openvpn_config.sh`

Selects a random `.ovpn` from `/data/openvpn-configs` and installs it as active OpenVPN config.

Prepare source directory:

```text
mkdir -p /data/openvpn-configs
# copy your *.ovpn files (and referenced cert/key files) into /data/openvpn-configs
```

Manual run:

```text
/data/scripts/select_random_openvpn_config.sh
```

Scheduled rotation:

```text
VPN_CRON_SCHEDULE=30 */12 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_openvpn_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

## `rotate_on_poor_speed.sh`

Measures connection quality and rotates profiles when poor performance persists.

Behavior:

- Runs lightweight `curl` speed/latency tests across one or more endpoints.
- Supports multi-endpoint checks with per-endpoint retries and weighted aggregation.
- Increments a persistent failure streak when aggregated speed is too low, latency too high, or too few endpoints succeed.
- Rotates only after `ROTATE_FAIL_STREAK` consecutive poor runs.
- Applies cooldown (`ROTATE_COOLDOWN_SECONDS`) to avoid rapid flip-flopping.
- Uses your existing profile scripts:
  - WireGuard: `select_random_wireguard_config.sh` (and optional `get_wireguard_configs_nordvpn.sh` refresh)
  - OpenVPN: `select_random_openvpn_config.sh`

Important variables:

```text
ROTATE_MODE=auto
ROTATE_SPEEDTEST_URLS=https://speed.cloudflare.com/__down?bytes=4000000,https://proof.ovh.net/files/10Mb.dat
ROTATE_SPEEDTEST_WEIGHTS=0.60,0.40
ROTATE_SPEEDTEST_URL=https://speed.cloudflare.com/__down?bytes=4000000
ROTATE_SPEEDTEST_TIMEOUT=20
ROTATE_SPEEDTEST_ATTEMPTS=1
ROTATE_MIN_SUCCESSFUL_ENDPOINTS=1
ROTATE_MIN_DOWNLOAD_MBPS=10
ROTATE_MAX_LATENCY_MS=700
ROTATE_FAIL_STREAK=3
ROTATE_COOLDOWN_SECONDS=1800
ROTATE_STATE_FILE=/data/rotate-on-poor-speed-state
ROTATE_WIREGUARD_SCRIPT=/data/scripts/select_random_wireguard_config.sh
ROTATE_OPENVPN_SCRIPT=/data/scripts/select_random_openvpn_config.sh
ROTATE_WIREGUARD_REFRESH_ENABLED=no
ROTATE_WIREGUARD_REFRESH_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
ROTATE_POST_ROTATION_ACTION=none
ROTATE_RESTART_REQUEST_FILE=/tmp/rotate-on-poor-speed-exit-watchdog
```

Notes:

- `ROTATE_SPEEDTEST_URLS` is the preferred multi-endpoint setting (comma-separated URLs).
- `ROTATE_SPEEDTEST_WEIGHTS` is optional (comma-separated positive numbers) and must match endpoint count when set.
- `ROTATE_SPEEDTEST_URL` remains supported for backward compatibility and is used as fallback when `ROTATE_SPEEDTEST_URLS` is unset.
- Aggregated decision uses weighted speed/latency from endpoints with at least one successful probe.
- `ROTATE_MIN_SUCCESSFUL_ENDPOINTS` controls how many endpoints must succeed before thresholds are evaluated.

`ROTATE_MODE` values:

- `auto`: infer mode from `VPN_CLIENT`
- `wireguard`: force WireGuard rotation
- `openvpn`: force OpenVPN rotation

Post-rotation action:

- `ROTATE_POST_ROTATION_ACTION=none` (default): rotate config only.
- `ROTATE_POST_ROTATION_ACTION=watchdog-exit`: write restart request file so `watchdog.sh` exits and Docker restart policy can recreate the container.

Important:

- For `ROTATE_POST_ROTATION_ACTION=watchdog-exit`, configure Docker/Compose restart policy (recommended: `restart: unless-stopped`), otherwise the container exits and stays down.

Manual run:

```text
/data/scripts/rotate_on_poor_speed.sh
```

Scheduled run example (dedicated scheduler, enabled by default):

```text
ROTATE_ON_POOR_SPEED_ENABLED=yes
ROTATE_ON_POOR_SPEED_SCHEDULE=*/20 * * * *
ROTATE_ON_POOR_SPEED_SCRIPT=/data/scripts/rotate_on_poor_speed.sh
ROTATE_ON_POOR_SPEED_TIMEOUT=90
ROTATE_MODE=auto
ROTATE_FAIL_STREAK=3
ROTATE_COOLDOWN_SECONDS=1800
```

Set `ROTATE_ON_POOR_SPEED_ENABLED=no` to disable this scheduler without touching `VPN_CRON_*`.

## `benchmark_endpoints.sh`

Benchmarks multiple endpoints and chooses the best candidate based on combined speed/latency score.

Behavior:

- Runs `curl` probes per endpoint.
- Measures:
  - `time_starttransfer` (latency proxy, ms)
  - `speed_download` (Mbps)
- Computes score: higher speed + lower latency wins.
- Prints per-endpoint results and best endpoint to stdout.
- Optionally writes:
  - best endpoint to `BENCHMARK_BEST_FILE`
  - full JSON report to `BENCHMARK_OUTPUT_FILE`

Important variables:

```text
BENCHMARK_ENDPOINTS=https://speed.cloudflare.com/__down?bytes=4000000,https://proof.ovh.net/files/10Mb.dat
BENCHMARK_ATTEMPTS=2
BENCHMARK_TIMEOUT=20
BENCHMARK_BEST_FILE=/data/benchmark-best-endpoint.txt
BENCHMARK_OUTPUT_FILE=/data/benchmark-endpoints.json
```

Manual run:

```text
/data/scripts/benchmark_endpoints.sh
```

Scheduled run example:

```text
VPN_CRON_SCHEDULE=*/30 * * * *
VPN_CRON_SCRIPT=/data/scripts/benchmark_endpoints.sh
VPN_CRON_SCRIPT_TIMEOUT=90
```

## `backup_config.sh`

Creates `tar.gz` backups of `/config` (default source) and stores them in `/data/backups` (default target).

Important variables:

```text
BACKUP_SOURCE_DIR=/config
BACKUP_TARGET_DIR=/data/backups
BACKUP_FILENAME_PREFIX=nzbgetvpn-config-backup
BACKUP_KEEP_COUNT=10
NZBGETVPN_TIMESTAMP_TZ=utc
```

Manual backup:

```text
/data/scripts/backup_config.sh
```

Scheduled backup:

```text
BACKUP_CRON_SCHEDULE=0 */6 * * *
BACKUP_CRON_SCRIPT=/data/scripts/backup_config.sh
BACKUP_CRON_SCRIPT_TIMEOUT=300
BACKUP_SOURCE_DIR=/config
BACKUP_TARGET_DIR=/data/backups
BACKUP_FILENAME_PREFIX=nzbgetvpn-config
BACKUP_KEEP_COUNT=20
NZBGETVPN_TIMESTAMP_TZ=utc
```

Notes:

- `BACKUP_TARGET_DIR` is created automatically when missing.
- `NZBGETVPN_TIMESTAMP_TZ=local` switches timestamp formatting to local container time.

## `log_sanitizer.sh`

Sanitizes log output before sharing it externally. The helper redacts:

- common token/secret assignments and bearer tokens
- IPv4 and IPv6 addresses
- absolute filesystem paths

Where to run it:

- Preferred: inside the container (`/data/scripts/log_sanitizer.sh` is always present there).
- Optional: on the Docker host only when `/data` is bind-mounted and the same script path exists on the host.

Manual run:

```text
/data/scripts/log_sanitizer.sh /data/nzbgetvpn.log /data/nzbgetvpn.sanitized.log
```

Pipe Docker logs:

```text
docker logs nzbgetvpn 2>&1 | /data/scripts/log_sanitizer.sh > /data/nzbgetvpn-dockerlogs.sanitized.log
```

## `upgrade_check.sh`

Checks whether a newer NZBGetVPN image/codebase version is available, checks NZBGet app version drift (stable/testing), then prints changelog impact before you update.

When GitHub metadata cannot be reached (for example DNS/network timeout inside container), the script logs warnings and exits successfully after local checks, so it can be used safely in cron workflows.

Manual run:

```text
/data/scripts/upgrade_check.sh
```

Optional variables:

```text
UPGRADE_CHECK_REPO=marc0janssen/nzbgetvpn
UPGRADE_CHECK_BRANCH=develop
UPGRADE_CHECK_CHANNEL=stable
UPGRADE_CHECK_TIMEOUT=15
UPGRADE_CHECK_CHANGELOG_LIMIT=4
UPGRADE_CHECK_LOCAL_VERSION_FILE=/usr/local/share/nzbgetvpn/VERSION
UPGRADE_CHECK_LOCAL_NZBGET_VERSION=26.1
```

Example scheduled check:

```text
VPN_CRON_SCHEDULE=0 8 * * *
VPN_CRON_SCRIPT=/data/scripts/upgrade_check.sh
VPN_CRON_SCRIPT_TIMEOUT=60
```

## Notification Scripts

These scripts can be used for:

- self-test state transitions (`NOTIFY_SELFTEST_STATE_SCRIPT`)
- unhealthy threshold events (`NOTIFY_UNHEALTHY_SCRIPT`)

Common optional override:

```text
NOTIFY_MESSAGE=Custom message text
```

Self-test transition context variables (provided by runtime):

```text
VPN_SELFTEST_PREVIOUS_STATE
VPN_SELFTEST_CURRENT_STATE
VPN_SELFTEST_WARN_COUNT
VPN_SELFTEST_FAIL_COUNT
```

### `notify_discord.sh`

Required:

```text
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Optional:

```text
DISCORD_USERNAME=NZBGetVPN
DISCORD_AVATAR_URL=https://example.com/icon.png
DISCORD_MENTIONS=@everyone
```

Self-test transition example:

```text
VPN_SELFTEST_ENABLED=*/2 * * * *
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify_discord.sh
NOTIFY_SELFTEST_STATE_TIMEOUT=30
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Unhealthy notification example:

```text
NOTIFY_UNHEALTHY_SCRIPT=/data/scripts/notify_discord.sh
NOTIFY_UNHEALTHY_TIMEOUT=300
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

### `notify_telegram.sh`

Required:

```text
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_CHAT_ID=-1001234567890
```

Optional:

```text
TELEGRAM_MESSAGE_THREAD_ID=123
TELEGRAM_PARSE_MODE=Markdown
```

Self-test transition example:

```text
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify_telegram.sh
NOTIFY_SELFTEST_STATE_TIMEOUT=30
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_CHAT_ID=-1001234567890
```

### `notify_pushover.sh`

Required:

```text
PUSHOVER_APP_TOKEN=your-app-token
PUSHOVER_USER_KEY=your-user-key
```

Optional:

```text
PUSHOVER_TITLE=NZBGetVPN
PUSHOVER_PRIORITY=0
PUSHOVER_DEVICE=iphone
PUSHOVER_SOUND=pushover
```

Self-test transition example:

```text
NOTIFY_SELFTEST_STATE_SCRIPT=/data/scripts/notify_pushover.sh
NOTIFY_SELFTEST_STATE_TIMEOUT=30
PUSHOVER_APP_TOKEN=your-app-token
PUSHOVER_USER_KEY=your-user-key
```

## Complete `docker-compose.yml` Examples (with remarks)

Below are complete examples focused on helper-script usage patterns.

### Example A: WireGuard random rotation + scheduled backups

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    container_name: nzbgetvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "6789:6789"
    environment:
      VPN_ENABLED: "yes"
      VPN_CLIENT: "wireguard"
      VPN_PROV: "custom"
      LAN_NETWORK: "192.168.1.0/24"

      # Rotate WireGuard profile every 12 hours.
      VPN_CRON_SCHEDULE: "0 */12 * * *"
      VPN_CRON_SCRIPT: "/data/scripts/select_random_wireguard_config.sh"
      VPN_CRON_SCRIPT_TIMEOUT: "300"

      # Independent backup scheduler every 6 hours.
      BACKUP_CRON_SCHEDULE: "0 */6 * * *"
      BACKUP_CRON_SCRIPT: "/data/scripts/backup_config.sh"
      BACKUP_CRON_SCRIPT_TIMEOUT: "300"
      BACKUP_SOURCE_DIR: "/config"
      BACKUP_TARGET_DIR: "/data/backups"
      BACKUP_FILENAME_PREFIX: "nzbgetvpn-config"
      BACKUP_KEEP_COUNT: "20"
      NZBGETVPN_TIMESTAMP_TZ: "utc"

    volumes:
      - ./config:/config
      - ./data:/data
    restart: unless-stopped
```

Remarks:

- Put multiple WireGuard `*.conf` files in `./data/wireguard-configs`.
- `NZBGETVPN_TIMESTAMP_TZ=utc` gives `Z`-suffixed timestamps for backups/markers/status.
- Keep `./data/backups` private; it may contain sensitive config and provider material.

### Example B: OpenVPN random rotation + Discord self-test transitions

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    container_name: nzbgetvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "6789:6789"
    environment:
      VPN_ENABLED: "yes"
      VPN_CLIENT: "openvpn"
      VPN_PROV: "custom"
      LAN_NETWORK: "192.168.1.0/24"

      # Rotate OpenVPN profile every 12 hours.
      VPN_CRON_SCHEDULE: "30 */12 * * *"
      VPN_CRON_SCRIPT: "/data/scripts/select_random_openvpn_config.sh"
      VPN_CRON_SCRIPT_TIMEOUT: "300"

      # Continuous self-test + ready/status files.
      VPN_SELFTEST_ENABLED: "*/2 * * * *"
      VPN_SELFTEST_READY_FILE: "/data/.nzbgetvpn-ready"
      VPN_SELFTEST_STATUS_FILE: "/data/.nzbgetvpn-status.json"
      VPN_SELFTEST_READY_STRICT: "yes"
      NZBGETVPN_TIMESTAMP_TZ: "local"

      # Notify only on readiness transitions.
      NOTIFY_SELFTEST_STATE_SCRIPT: "/data/scripts/notify_discord.sh"
      NOTIFY_SELFTEST_STATE_TIMEOUT: "30"
      DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/REPLACE/ME"
      DISCORD_USERNAME: "NZBGetVPN"

    volumes:
      - ./config:/config
      - ./data:/data
    restart: unless-stopped
```

Remarks:

- Put multiple OpenVPN `*.ovpn` files in `./data/openvpn-configs` (plus referenced cert/key files).
- `NZBGETVPN_TIMESTAMP_TZ=local` uses container local time for ready/status/backups.
- Self-test notifications trigger only on `ready <-> not_ready` transitions, not on every run.

### Example C: NordVPN config refresh on unhealthy + Telegram alert

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    container_name: nzbgetvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "6789:6789"
    environment:
      VPN_ENABLED: "yes"
      VPN_CLIENT: "wireguard"
      VPN_PROV: "custom"
      LAN_NETWORK: "192.168.1.0/24"

      # Refresh NordVPN configs every 6 hours.
      VPN_CRON_SCHEDULE: "0 */6 * * *"
      VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
      VPN_CRON_SCRIPT_TIMEOUT: "300"
      NORDVPN_ACCESS_TOKEN: "REPLACE_WITH_YOUR_TOKEN"

      # If unhealthy threshold is hit: refresh config and exit.
      VPN_UNHEALTHY_ACTION: "script+exit"
      VPN_UNHEALTHY_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
      VPN_UNHEALTHY_SCRIPT_TIMEOUT: "300"
      VPN_UNHEALTHY_AFTER: "10"
      VPN_UNHEALTHY_COOLDOWN: "300"
      VPN_UNHEALTHY_EXIT_DELAY: "5"

      # Dedicated unhealthy notification.
      NOTIFY_UNHEALTHY_SCRIPT: "/data/scripts/notify_telegram.sh"
      NOTIFY_UNHEALTHY_TIMEOUT: "300"
      TELEGRAM_BOT_TOKEN: "123456:ABCDEF_REPLACE_ME"
      TELEGRAM_CHAT_ID: "-1001234567890"

    volumes:
      - ./config:/config
      - ./data:/data
    restart: unless-stopped
```

Remarks:

- Rotate/revoke `NORDVPN_ACCESS_TOKEN` if exposed.
- With `script+exit`, container exits only after the script succeeds; pair with restart policy.
- Use `VPN_UNHEALTHY_TEST=yes` only temporarily for validation, then remove it.

## Permissions

Make sure custom scripts are executable:

```text
chmod +x /data/scripts/my-script.sh
```

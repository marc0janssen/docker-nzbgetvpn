# NZBGetVPN

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with VPN leak protection, OpenVPN, WireGuard, Privoxy and optional user hooks.

This image builds on top of [`binhex/arch-int-vpn`](https://github.com/binhex/arch-int-vpn). That base image provides the VPN framework, firewall approach, provider handling, Privoxy/SOCKS support and most VPN recovery behavior. This repository adds NZBGet, stricter build verification, NZBGet startup handling, firewall input validation, readable logging, update scripts, and optional custom scripts for VPN unhealthy or scheduled maintenance events.

[Thanks for the tip!](https://ko-fi.com/marc0janssen)

## Versions

[NZBGet release information](https://github.com/nzbgetcom/nzbget/releases)

* NZBGetVPN image/codebase version: 4.16.2
* NZBGET Current stable version: 26.1
* NZBGET Current testing version: 26.2-testing-20260506

The NZBGetVPN image/codebase version is stored in `VERSION`. The two NZBGet version lines are intentionally kept in this exact format. The update scripts use them when bumping stable or testing releases.

## Image Tags

| Tag | Purpose |
| --- | --- |
| `marc0janssen/nzbgetvpn:stable` | Stable NZBGet release from `Dockerfile`. |
| `marc0janssen/nzbgetvpn:testing` | Testing NZBGet release from `Dockerfile-testing`. |
| `marc0janssen/nzbgetvpn:<version>` | Versioned image, for example `26.1` or `26.2-testing-20260504`. |
| `marc0janssen/nzbgetvpn:<nzbget-version>-image-v<version>` | Image tagged with both the NZBGet version and the NZBGetVPN codebase version from `VERSION`, for example `26.1-image-v4.16.2`. |

## What Is Included

| Component | Port / path | Notes |
| --- | --- | --- |
| NZBGet web UI | `6789/tcp` | Default login is documented below. Change it after first start. |
| Privoxy | `8118/tcp` | Inherited from the base image, enabled with `ENABLE_PRIVOXY=yes`. |
| SOCKS proxy | Base-image controlled | Inherited from `binhex/arch-int-vpn`, enabled with `ENABLE_SOCKS=yes`. |
| OpenVPN | `/config/openvpn/` | Put one `.ovpn` profile and its referenced files here. |
| WireGuard | `/config/wireguard/` | Put one `.conf` profile here. The base image normalizes it to `wg0.conf`. |
| NZBGet config | `/config/nzbget.conf` | Created on first start if missing. |
| Downloads/data | `/data` | Main download and script storage volume. |
| Bundled scripts | `/data/scripts/` | Helper scripts included in the image, including NordVPN WireGuard config generation. |
| Leak protection | iptables | VPN, LAN and UI traffic are explicitly allowed; other traffic is dropped. |

## Default Credentials

Default NZBGet login is `nzbget` / `tegbzn6789`. Change it immediately after first start and do not expose the web UI directly to the internet without an authenticated reverse proxy or VPN access.

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

Open the NZBGet UI at:

```text
http://<host-ip>:6789
```

When Privoxy is enabled, configure clients to use:

```text
http://<host-ip>:8118
```

## Docker Compose

Ready-to-edit Compose examples live in [`examples/`](examples/).

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    container_name: nzbgetvpn
    cap_add:
      - NET_ADMIN
    ports:
      - "6789:6789/tcp"
      - "8118:8118/tcp"
    volumes:
      - /path/to/config:/config
      - /path/to/data:/data
      - /etc/localtime:/etc/localtime:ro
    environment:
      VPN_ENABLED: "yes"
      VPN_CLIENT: "openvpn"
      VPN_PROV: "custom"
      LAN_NETWORK: "192.168.1.0/24"
      NAME_SERVERS: "1.1.1.1,1.0.0.1"
      ENABLE_PRIVOXY: "yes"
      STRICT_PORT_FORWARD: "no"
      UMASK: "000"
      PUID: "1000"
      PGID: "1000"
    restart: unless-stopped
```

For WireGuard, replace `cap_add` with:

```yaml
privileged: true
sysctls:
  net.ipv4.conf.all.src_valid_mark: "1"
```

Compose mapping form is recommended for values that contain spaces, especially cron schedules:

```yaml
environment:
  VPN_CRON_SCHEDULE: "*/5 * * * *"
  VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
```

If you use Compose list form, do not add quotes after `=`:

```yaml
environment:
  - VPN_CRON_SCHEDULE=*/5 * * * *
  - VPN_CRON_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
```

## Volumes And Permissions

| Path | Required | Description |
| --- | --- | --- |
| `/config` | Yes | Persistent config, NZBGet config, OpenVPN profiles and WireGuard profiles. |
| `/data` | Yes | Downloads, intermediate files and optional user scripts. |
| `/etc/localtime:ro` | Recommended | Keeps container time aligned with the host. Useful for logs and cron-style schedules. |

Runtime ownership is controlled with `PUID` and `PGID`. Find your host IDs with:

```sh
id <username>
```

The image includes helper script templates. On container start, bundled scripts are copied into `/data/scripts/` and updated when the image template differs from the mounted copy. The default source directories `/data/wireguard-configs`, `/data/openvpn-configs`, and `/data/backups` are also created. Each of these `/data` subdirectories gets a small `README.md`. If you bind mount a host directory over `/data`, startup recreates these missing directories and README files in that mounted directory.

Bundled notification examples are also available:

- `/data/scripts/notify_discord.sh`
- `/data/scripts/notify_telegram.sh`
- `/data/scripts/notify_pushover.sh`

They are designed for `NOTIFY_SELFTEST_STATE_SCRIPT` and `NOTIFY_UNHEALTHY_SCRIPT` workflows.
The bundle also includes `/data/scripts/log_sanitizer.sh` to sanitize logs before sharing and `/data/scripts/upgrade_check.sh` for pre-update checks.

## Backup And Restore

Back up `/config` and `/data` together. `/config` contains NZBGet configuration, provider profiles, OpenVPN files and WireGuard files. `/data` contains downloads, bundled helper script copies and optional user data.

Simple tar backup:

```sh
tar -czf nzbgetvpn-backup.tgz /path/to/config /path/to/data
```

Simple restore:

```sh
tar -xzf nzbgetvpn-backup.tgz -C /
```

Stop the container before backing up or restoring if you need a point-in-time copy. Keep backup archives private because they may contain VPN profiles, keys, NZBGet credentials or provider tokens.

## Security

See [`SECURITY.md`](SECURITY.md) for vulnerability reporting and scope. Do not put secrets, VPN profiles, keys, tokens or `.env` files in issues, pull requests or this repository.

## Base Image Capabilities

The table below describes the important `binhex/arch-int-vpn` behavior this image inherits. Provider support can change when the base image changes, so pin and bump the base tag deliberately when reproducibility matters.

| Capability | Provided by base image | How to use it here |
| --- | --- | --- |
| OpenVPN client | Yes | Set `VPN_CLIENT=openvpn` and place one `.ovpn` file in `/config/openvpn/`. |
| WireGuard client | Yes | Set `VPN_CLIENT=wireguard` and place one `.conf` file in `/config/wireguard/`, unless the provider integration generates it. |
| VPN reconnect/healing | Yes | OpenVPN runs in a reconnect loop. WireGuard is monitored and cycled when the peer disappears. |
| iptables leak protection | Yes, extended here | The base image builds the VPN environment. This repo adds stricter input validation and NZBGet-specific port rules. |
| Privoxy | Yes | Set `ENABLE_PRIVOXY=yes`, expose `8118/tcp`. |
| SOCKS proxy | Yes | Set `ENABLE_SOCKS=yes`; optionally set `SOCKS_USER` and `SOCKS_PASS`. |
| Provider support | Yes | Use `VPN_PROV` values supported by the base image, such as `pia`, `airvpn`, `custom`, `nordvpn` where available. |
| PIA port forwarding | Yes | Controlled by base-image provider logic and `STRICT_PORT_FORWARD`. |
| Startup scripts | Yes | Set `ENABLE_STARTUP_SCRIPTS=yes` and place shell scripts in `/config/scripts/`. |
| Userspace WireGuard | Yes | Set `USERSPACE_WIREGUARD=yes` when kernel WireGuard is unavailable. |
| Host networking | No | The base image rejects host network mode. Use bridge networking with exposed ports. |

## Environment Variables

### Core Settings

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_ENABLED` | Usually | `yes`, `no` | Base-image controlled | Enables or disables VPN handling. Use `no` only when you deliberately want NZBGet without VPN. |
| `VPN_CLIENT` | When VPN is enabled | `openvpn`, `wireguard` | `openvpn` if empty in the base image | Selects the VPN implementation. |
| `VPN_PROV` | When VPN is enabled | Provider key | unset | Provider profile consumed by the base image. Common values include `custom`, `pia`, `airvpn`, `nordvpn`. |
| `LAN_NETWORK` | When VPN is enabled | IPv4 CIDR list | unset | LAN networks allowed to reach local container services. Example: `192.168.1.0/24`. |
| `NAME_SERVERS` | Recommended | IPv4 list | `1.1.1.1,1.0.0.1` in the base image | DNS servers used inside the VPN framework. |
| `PUID` | No | Numeric UID | Base-image controlled | User ID for file ownership. |
| `PGID` | No | Numeric GID | Base-image controlled | Group ID for file ownership. |
| `UMASK` | No | Octal mask | Base-image controlled | File creation mask, for example `000`, `002`, `022`. |
| `DEBUG` | No | `true`, `false` | `false` | Enables extra script output where supported. |
| `VPN_HEALTHCHECK_ENABLED` | No | `yes`, `no`, `true`, `false`, `1`, `0` | `yes` | Controls Docker `HEALTHCHECK` probes. Set `no` to force healthcheck success while keeping other runtime behavior unchanged. |
| `VPN_SELFTEST_ENABLED` | No | `no`, `yes`, cron expression | `no` | Controls internal VPN self-test scheduling. `false`/`0` map to `no`, `true`/`1` map to `yes`. |
| `VPN_SELFTEST_STARTUP_DELAY` | No | Non-negative integer seconds | `20` | Delay before one-shot self-test when `VPN_SELFTEST_ENABLED=yes`. Helps avoid startup timing warnings. Values above `300` are clamped to `300`. |
| `VPN_SELFTEST_NZBGET_PORT` | No | TCP port `1-65535` | `6789` | NZBGet TCP port used by self-test listen checks in watchdog and Docker health probes. Invalid values fall back to `6789` with a warning. |
| `VPN_SELFTEST_STATE_FILE` | No | Absolute path | `/data/nzbgetvpn-selftest-state` | State file used to persist last readiness state between self-test runs. If this default file exists but is not writable by the current runtime user, self-test falls back to `/data/nzbgetvpn-selftest-state-uid<uid>`. |
| `VPN_SELFTEST_DEBOUNCE_CRIT` | No | Positive integer | `1` | Critical-failure debounce threshold: number of consecutive self-test runs with critical failures before state becomes `not_ready` and the script exits non-zero. |
| `VPN_SELFTEST_DEBOUNCE_WARN` | No | Positive integer | `1` | Strict-warning debounce threshold: when `VPN_SELFTEST_READY_STRICT=yes`, number of consecutive runs with warnings before state becomes `not_ready`. |
| `VPN_SELFTEST_DEBOUNCE_FILE` | No | Absolute path | `/data/nzbgetvpn-selftest-debounce` | File storing debounce streak counters for consecutive failures/warnings (atomic, best-effort). If this default file exists but is not writable by the current runtime user, self-test falls back to `/data/nzbgetvpn-selftest-debounce-uid<uid>`. |
| `VPN_SELFTEST_STATUS_FILE` | No | Absolute path | unset | When set, self-test writes a one-line JSON status snapshot (atomic replace) with timezone-aware `timestamp`, `timestamp_tz`, legacy `timestamp_utc`, readiness state, warning/failure counts and key context. |
| `VPN_SELFTEST_READY_FILE` | No | Absolute filesystem path | unset | When set, successful self-test writes one line `ok <timestamp>` here (atomic); critical failure removes the file. On watchdog startup, any stale file at this path is cleared before new self-test runs. Parent directory must exist and be writable. |
| `VPN_SELFTEST_READY_STRICT` | No | `yes`, `no`, `true`, `false`, `1`, `0` | `no` | If truthy, the ready file is written only when there are zero warnings; otherwise the file is removed. |
| `NZBGETVPN_TIMESTAMP_TZ` | No | `utc`, `local` | `utc` | Timezone mode used by generated ready-file, self-test status JSON timestamp, and backup timestamps. `utc` keeps `Z`-suffixed UTC stamps; `local` uses container local time. |

### Notification Settings

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `NOTIFY_SELFTEST_STATE_SCRIPT` | No | Executable absolute path | unset | Dedicated notify script for self-test state transitions (`ready` <-> `not_ready`). |
| `NOTIFY_SELFTEST_STATE_TIMEOUT` | No | Positive integer seconds | `30` | Timeout for `NOTIFY_SELFTEST_STATE_SCRIPT`. |
| `NOTIFY_UNHEALTHY_SCRIPT` | No | Executable path | unset | Dedicated notify script run when VPN unhealthy threshold is reached. |
| `NOTIFY_UNHEALTHY_TIMEOUT` | No | Positive integer seconds | `300` | Timeout for `NOTIFY_UNHEALTHY_SCRIPT`. |

### VPN Provider And Client Settings

| Variable | Required | Values / format | Description |
| --- | --- | --- | --- |
| `VPN_USER` | Provider-dependent | String | VPN username. Not always needed for profile/certificate based setups. |
| `VPN_PASS` | Provider-dependent | String | VPN password. |
| `VPN_OPTIONS` | No | OpenVPN options | Extra options passed to OpenVPN. Only relevant for `VPN_CLIENT=openvpn`. |
| `STRICT_PORT_FORWARD` | No | `yes`, `no` | Base-image port-forward behavior, mainly relevant for providers that support it, especially PIA. |
| `USERSPACE_WIREGUARD` | No | `yes`, `no` | Uses userspace WireGuard when kernel WireGuard cannot be used. |
| `ENABLE_STARTUP_SCRIPTS` | No | `yes`, `no` | Runs `/config/scripts/*.sh` during startup before the main app flow. |

### Proxy Settings

| Variable | Required | Values / format | Description |
| --- | --- | --- | --- |
| `ENABLE_PRIVOXY` | No | `yes`, `no` | Enables Privoxy on `8118/tcp`. |
| `ENABLE_SOCKS` | No | `yes`, `no` | Enables the inherited SOCKS proxy. |
| `SOCKS_USER` | No | String | Enables SOCKS authentication when set. If unset, SOCKS auth is disabled. |
| `SOCKS_PASS` | No | String | SOCKS password. The base image defaults this to `socks` when `SOCKS_USER` is set and the password is empty. |

### Firewall And Internal VPN Values

Most users should not set these manually. They are usually derived from OpenVPN/WireGuard config by the base image, but this repo validates or consumes them in `run/root/iptable.sh`.

| Variable | Usually set by | Values / format | Description |
| --- | --- | --- | --- |
| `VPN_REMOTE_SERVER` | Base image | Hostname or IP | VPN endpoint host. |
| `VPN_REMOTE_PORT` | Base image | Port list | VPN endpoint ports allowed outside the tunnel. Startup fails if missing or invalid during firewall setup. |
| `VPN_REMOTE_PROTOCOL` | Base image | `udp`, `tcp`, `tcp-client` | VPN endpoint protocol. |
| `VPN_DEVICE_TYPE` | Base image | Interface name | Tunnel interface such as `tun0` or `wg0`. |
| `VPN_CONFIG` | Base image | Path | Generated or normalized VPN config path. |
| `VPN_INPUT_PORTS` | Base image | Port list | Additional incoming ports supported by the base image. Prefer this over `ADDITIONAL_PORTS` for new setups. |
| `VPN_OUTPUT_PORTS` | Base image | Port list | Additional outgoing ports supported by the base image. |
| `ADDITIONAL_PORTS` | This repo / legacy | Port list | Extra TCP and UDP ports allowed through this repo's firewall script. Kept for compatibility. |

### VPN Unhealthy Actions

Normal VPN auto-healing comes from the base image. These variables add an extra fallback in this image: if the watchdog cannot see a VPN IP for several checks, it can run your own script, exit the container, or do both.

The watchdog loop runs every 30 seconds.

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_UNHEALTHY_ACTION` | No | `none`, `script`, `script+exit`, `exit` | `none` | Action when VPN health keeps failing. |
| `VPN_FAILSAFE_NZBGET_ACTION` | No | `none`, `pause`, `stop` | `none` | Optional app-level fail-safe when unhealthy threshold is reached. `pause` runs `nzbget -P`; `stop` runs `nzbget -Q`. |
| `VPN_UNHEALTHY_SCRIPT` | For `script` / `script+exit` | Executable path | unset | Script to run when the unhealthy action needs a script. |
| `VPN_UNHEALTHY_AFTER` | No | Positive integer | `10` | Number of failed watchdog checks before action. `10` is about 5 minutes. |
| `VPN_UNHEALTHY_COOLDOWN` | No | Positive integer seconds | `300` | Minimum time between repeated actions. Values below `300` are raised to `300` and logged. |
| `VPN_UNHEALTHY_EXIT_DELAY` | No | Positive integer seconds | `5` | Delay before exit when `VPN_UNHEALTHY_ACTION=script+exit`. Exit only happens after the script succeeds. |
| `VPN_UNHEALTHY_SCRIPT_TIMEOUT` | No | Positive integer seconds | `300` | Maximum runtime for the custom script when `timeout` is available. |
| `VPN_UNHEALTHY_TEST` | No | `yes`, `no` | `no` | Makes the watchdog pretend the VPN IP is missing so you can test the action. |

Dedicated notifications can run independently through `NOTIFY_UNHEALTHY_SCRIPT` (without requiring `VPN_UNHEALTHY_ACTION=script`).
App-level fail-safe behavior is independent from firewall/killswitch behavior: when `VPN_FAILSAFE_NZBGET_ACTION` is `pause` or `stop`, watchdog triggers the NZBGet command once after the unhealthy threshold and resets this one-shot guard after VPN IP recovery.

Recovery behavior after VPN returns:

- `VPN_FAILSAFE_NZBGET_ACTION=stop`: watchdog starts NZBGet again automatically when VPN IP is detected and NZBGet is not running.
- `VPN_FAILSAFE_NZBGET_ACTION=pause`: NZBGet process keeps running, but downloads stay paused until you resume manually (WebUI/API/CLI).
- `VPN_FAILSAFE_NZBGET_ACTION=none`: no app-level pause/stop action is applied.

Example:

```sh
-e VPN_UNHEALTHY_ACTION=script+exit \
-e VPN_UNHEALTHY_SCRIPT=/config/scripts/vpn-unhealthy.sh \
-e VPN_UNHEALTHY_AFTER=10 \
-e VPN_UNHEALTHY_COOLDOWN=300 \
-e VPN_UNHEALTHY_EXIT_DELAY=5
```

The script receives `VPN_UNHEALTHY_COUNT` in its environment. If the script is missing, not executable, fails, or times out, this is logged and the container keeps running. For `script+exit`, the container exits only after the script finishes successfully. Use a Docker restart policy if you want Docker to start it again.

Testing:

```sh
-e VPN_UNHEALTHY_TEST=yes \
-e VPN_UNHEALTHY_AFTER=1
```

Remove `VPN_UNHEALTHY_TEST=yes` after testing. With `script+exit` and `restart: unless-stopped`, this can intentionally restart repeatedly until the test flag is removed.

### Scheduled VPN Scripts

`VPN_CRON_*` runs a custom script from the existing watchdog loop. It is cron-style scheduling without a separate cron daemon.

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_CRON_SCHEDULE` | With `VPN_CRON_SCRIPT` | Five-field cron expression | unset | Supports `*`, lists, ranges and steps, for example `*/5 * * * *`. |
| `VPN_CRON_SCRIPT` | With `VPN_CRON_SCHEDULE` | Executable path | unset | Script to run when the schedule matches. |
| `VPN_CRON_SCRIPT_TIMEOUT` | No | Positive integer seconds | `300` | Maximum runtime for the script when `timeout` is available. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "*/5 * * * *"
  VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
  VPN_CRON_SCRIPT_TIMEOUT: "300"
```

The watchdog checks the schedule every 30 seconds, before the blocking VPN checks run. A matching cron minute runs only once. The script receives `VPN_CRON_SCHEDULE` in its environment. If the schedule or script is incomplete, missing, not executable, failed, or timed out, the error is logged and the container keeps running.

### Scheduled Config Backups

`BACKUP_CRON_*` schedules config backups independently from `VPN_CRON_*`.

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `BACKUP_CRON_SCHEDULE` | No | Five-field cron expression | unset | Dedicated backup scheduler. |
| `BACKUP_CRON_SCRIPT` | No | Executable path | `/data/scripts/backup_config.sh` | Backup script path used by `BACKUP_CRON_SCHEDULE`. |
| `BACKUP_CRON_SCRIPT_TIMEOUT` | No | Positive integer seconds | `300` | Timeout for `BACKUP_CRON_SCRIPT` when `timeout` is available. |
| `BACKUP_SOURCE_DIR` | No | Absolute path | `/config` | Source directory archived by the backup script. |
| `BACKUP_TARGET_DIR` | No | Absolute path | `/data/backups` | Backup destination directory; created automatically when missing. |
| `BACKUP_FILENAME_PREFIX` | No | `a-zA-Z0-9._-` | `nzbgetvpn-config-backup` | Prefix for generated archive filenames. |
| `BACKUP_KEEP_COUNT` | No | Non-negative integer | `10` | Number of newest backups to keep (`0` disables cleanup). |
| `NZBGETVPN_TIMESTAMP_TZ` | No | `utc`, `local` | `utc` | Timestamp mode for backup archive filenames (`...Z` in UTC mode, `...L` in local mode). |

Example:

```yaml
environment:
  BACKUP_CRON_SCHEDULE: "0 */6 * * *"
  BACKUP_CRON_SCRIPT: "/data/scripts/backup_config.sh"
  BACKUP_CRON_SCRIPT_TIMEOUT: "300"
  BACKUP_SOURCE_DIR: "/config"
  BACKUP_TARGET_DIR: "/data/backups"
  BACKUP_FILENAME_PREFIX: "nzbgetvpn-config"
  BACKUP_KEEP_COUNT: "20"
```

### Internal VPN Self-Test

This image includes an internal script at `/home/nobody/vpn-selftest.sh`. It is not installed in `/data/scripts`, so it is not exposed as a bundled helper template.

| Variable | Required | Values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_SELFTEST_ENABLED` | No | `no`, `yes`, cron expression | `no` | `yes` runs once at startup and cron values run on schedule. `true`/`1` behave as `yes`, `false`/`0` behave as `no`. |
| `VPN_SELFTEST_STARTUP_DELAY` | No | Non-negative integer seconds | `20` | Delay before one-shot self-test in `yes` mode. Values above `300` are clamped to `300`. |
| `VPN_SELFTEST_NZBGET_PORT` | No | TCP port `1-65535` | `6789` | Target NZBGet listen port for self-test checks. |
| `VPN_SELFTEST_STATE_FILE` | No | Absolute path | `/data/nzbgetvpn-selftest-state` | Stores previous readiness state for transition detection. If this default file exists but is not writable by the current runtime user, self-test falls back to `/data/nzbgetvpn-selftest-state-uid<uid>`. |
| `NOTIFY_SELFTEST_STATE_SCRIPT` | No | Executable absolute path | unset | Dedicated notify script called only when self-test state changes between `ready` and `not_ready`. |
| `NOTIFY_SELFTEST_STATE_TIMEOUT` | No | Positive integer seconds | `30` | Max runtime for self-test notify script when `timeout` is available. |
| `VPN_SELFTEST_DEBOUNCE_CRIT` | No | Positive integer | `1` | Debounce critical failures before switching to `not_ready` and exiting non-zero. |
| `VPN_SELFTEST_DEBOUNCE_WARN` | No | Positive integer | `1` | When strict mode is enabled, debounce warnings before switching to `not_ready`. |
| `VPN_SELFTEST_DEBOUNCE_FILE` | No | Absolute path | `/data/nzbgetvpn-selftest-debounce` | Stores consecutive critical/warning streak counters between runs. If this default file exists but is not writable by the current runtime user, self-test falls back to `/data/nzbgetvpn-selftest-debounce-uid<uid>`. |
| `VPN_SELFTEST_STATUS_FILE` | No | Absolute path | unset | Optional JSON status output for automation/monitoring, updated atomically after each self-test run; includes `timestamp`/`timestamp_tz` based on `NZBGETVPN_TIMESTAMP_TZ` and a legacy `timestamp_utc`. |
| `VPN_SELFTEST_READY_FILE` | No | Absolute path | unset | Optional ready signal: on success writes `ok <timestamp>` (atomic replace); on critical failure removes the file. On watchdog startup, stale files are cleared before fresh checks run. |
| `VPN_SELFTEST_READY_STRICT` | No | `yes`, `no`, `true`, `false`, `1`, `0` | `no` | If truthy, write the ready file only when there are zero warnings. |
| `NZBGETVPN_TIMESTAMP_TZ` | No | `utc`, `local` | `utc` | Timestamp mode for ready-marker output (`utc` = ISO8601 with `Z`, `local` = ISO8601 with local timezone offset). |

Examples:

```yaml
environment:
  VPN_SELFTEST_ENABLED: "yes"
```

```yaml
environment:
  VPN_SELFTEST_ENABLED: "*/5 * * * *"
```

```yaml
environment:
  VPN_SELFTEST_ENABLED: "yes"
  VPN_SELFTEST_READY_FILE: "/data/.nzbgetvpn-ready"
  VPN_SELFTEST_READY_STRICT: "yes"
```

The self-test does not modify routes, firewall rules, VPN profiles, or NZBGet state. It logs to container stdout with `[info]`, `[warn]`, and `[crit]` prefixes and returns an exit code. Optionally, `VPN_SELFTEST_READY_FILE` writes or removes a small marker file (see table above). With `VPN_SELFTEST_ENABLED=yes`, this is a startup snapshot: the marker reflects the one-shot result only. With a cron expression, it becomes continuous readiness: each scheduled run can update or clear the marker based on current state. When watchdog starts, it clears any stale marker file once before new checks run, so restarts begin in a not-ready state until a fresh self-test succeeds. The watchdog invokes the self-test at the end of each loop iteration (after `preruncheck` and any NZBGet start attempt), passes `vpn_ip` into the script, derives tunnel IPv4 from `VPN_DEVICE_TYPE` when `vpn_ip` is unset, and waits up to about 12 seconds for NZBGet to listen on the configured `VPN_SELFTEST_NZBGET_PORT` (default `6789`) before emitting a listen warning. If `NOTIFY_SELFTEST_STATE_SCRIPT` is set, the notify script runs only when readiness transitions (`ready` <-> `not_ready`) and receives `VPN_SELFTEST_PREVIOUS_STATE`, `VPN_SELFTEST_CURRENT_STATE`, `VPN_SELFTEST_WARN_COUNT`, and `VPN_SELFTEST_FAIL_COUNT`.

### Docker Healthcheck

Both `Dockerfile` and `Dockerfile-testing` define a native Docker `HEALTHCHECK`:

```text
interval=60s, timeout=30s, start-period=120s, retries=3
```

The healthcheck runs `/root/healthcheck.sh`, which executes the internal self-test and maps critical self-test failures to `unhealthy`. Warnings do not mark the container unhealthy. Healthcheck probes do not write ready marker files, status files, state files or debounce files, so `VPN_SELFTEST_READY_FILE`, `VPN_SELFTEST_STATUS_FILE`, `VPN_SELFTEST_STATE_*` and `VPN_SELFTEST_DEBOUNCE_FILE` behavior remain owned by watchdog-driven self-test scheduling.

Use `VPN_HEALTHCHECK_ENABLED=no` when you need Docker to always report healthy while still keeping the internal self-test feature available for logs/ready-marker workflows.

Healthchecks + notifications (Discord/Telegram/Pushover) are not built in, but can be integrated cleanly via `NOTIFY_SELFTEST_STATE_SCRIPT` (for `ready` -> `not_ready` transitions) or via `NOTIFY_UNHEALTHY_SCRIPT`.

### Docker Compose Orchestration Examples

Examples below show how to coordinate other containers with NZBGetVPN readiness using:

- Docker `HEALTHCHECK` (container becomes `healthy` / `unhealthy`)
- `VPN_SELFTEST_READY_FILE` (presence-based marker file)
- `VPN_SELFTEST_STATUS_FILE` (JSON details, including `state`)
- `NOTIFY_SELFTEST_STATE_SCRIPT` (trigger actions only on transitions)

#### Example: Gate a dependent service on Docker health

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    container_name: nzbgetvpn
    environment:
      VPN_ENABLED: "yes"
      VPN_SELFTEST_ENABLED: "*/1 * * * *"
    volumes:
      - ./config:/config
      - ./data:/data
    ports:
      - "6789:6789"

  depends-on-nzbgetvpn:
    image: alpine:3.20
    depends_on:
      nzbgetvpn:
        condition: service_healthy
    command: ["sh", "-c", "echo nzbgetvpn is healthy; sleep 3600"]
```

Notes:
- Compose health gating only works when the base Docker engine reports health and your Compose version supports `condition: service_healthy`.
- The built-in healthcheck maps critical self-test failures to `unhealthy`. Warnings remain `healthy`.

#### Example: Use the ready-file marker on a shared volume

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    environment:
      VPN_SELFTEST_ENABLED: "*/1 * * * *"
      VPN_SELFTEST_READY_FILE: "/data/.nzbgetvpn-ready"
      VPN_SELFTEST_READY_STRICT: "yes"
    volumes:
      - ./config:/config
      - ./data:/data

  wait-for-ready-file:
    image: alpine:3.20
    depends_on:
      - nzbgetvpn
    volumes:
      - ./data:/data
    command:
      - sh
      - -c
      - |
        echo "Waiting for /data/.nzbgetvpn-ready..."
        while [ ! -f /data/.nzbgetvpn-ready ]; do sleep 2; done
        echo "Ready file present."
        sleep 3600
```

#### Example: Use the status JSON (no ready-file needed)

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    environment:
      VPN_SELFTEST_ENABLED: "*/1 * * * *"
      VPN_SELFTEST_STATUS_FILE: "/data/.nzbgetvpn-status.json"
    volumes:
      - ./config:/config
      - ./data:/data

  wait-for-ready-status:
    image: alpine:3.20
    depends_on:
      - nzbgetvpn
    volumes:
      - ./data:/data
    command:
      - sh
      - -c
      - |
        echo "Waiting for status state=ready..."
        while true; do
          if [ -f /data/.nzbgetvpn-status.json ] && grep -q '"state":"ready"' /data/.nzbgetvpn-status.json; then
            break
          fi
          sleep 2
        done
        echo "Status is ready."
        sleep 3600
```

#### Example: Run a hook only when state changes

```yaml
services:
  nzbgetvpn:
    image: marc0janssen/nzbgetvpn:stable
    environment:
      VPN_SELFTEST_ENABLED: "*/1 * * * *"
      VPN_SELFTEST_STATE_FILE: "/data/.nzbgetvpn-selftest-state"
      NOTIFY_SELFTEST_STATE_SCRIPT: "/config/scripts/selftest-state-hook.sh"
      NOTIFY_SELFTEST_STATE_TIMEOUT: "30"
    volumes:
      - ./config:/config
      - ./data:/data
```

The hook receives:
`VPN_SELFTEST_PREVIOUS_STATE`, `VPN_SELFTEST_CURRENT_STATE`, `VPN_SELFTEST_WARN_COUNT`, and `VPN_SELFTEST_FAIL_COUNT`.

### Bundled NordVPN WireGuard Script

The image includes:

```text
/data/scripts/get_wireguard_configs_nordvpn.sh
```

This script fetches recommended NordVPN WireGuard servers and writes `.conf` files to `/config/wireguard/`. It can be used manually, with `VPN_CRON_SCRIPT`, or as part of a `VPN_UNHEALTHY_SCRIPT`.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `NORDVPN_ACCESS_TOKEN` | Yes | unset | NordVPN access token used to fetch the NordLynx private key. |
| `ACCESS_TOKEN` | No | unset | Backwards-compatible fallback when `NORDVPN_ACCESS_TOKEN` is unset. Prefer `NORDVPN_ACCESS_TOKEN`. |
| `COUNTRY_NAME` | No | `Netherlands` | NordVPN country name, for example `Netherlands`, `Germany`, `Belgium`. |
| `TOTAL_CONFIGS` | No | `1` | Number of NordVPN recommendations to fetch. If greater than `1`, one generated config is selected randomly. |
| `DNS` | No | `103.86.96.100` | DNS server written to the WireGuard config. |
| `WIREGUARD_CONFIG_DIR` | No | `/config/wireguard` | Output directory for generated `.conf` files. |
| `WIREGUARD_CONFIG_FILENAME` | No | `wg0.conf` | Target filename for the active config. Must end with `.conf` and may not contain `/`. |
| `WIREGUARD_CONFIG_USE_SOURCE_FILENAME` | No | `no` | Use `yes` to keep the generated NordVPN filename instead of `WIREGUARD_CONFIG_FILENAME`. |
| `WIREGUARD_ADDRESS` | No | `10.5.0.2/32` | Interface address written to the WireGuard config. |
| `WIREGUARD_PORT` | No | `51820` | WireGuard endpoint port. |

To create `NORDVPN_ACCESS_TOKEN`:

1. Log in to [Nord Account](https://my.nordaccount.com/).
2. Open `NordVPN`.
3. Go to `Advanced settings`.
4. Choose `Get access token`.
5. Verify your email address with the code Nord sends you.
6. Choose `Generate new token`.
7. Pick a temporary token or a non-expiring token.
8. Copy the token immediately; NordVPN only shows it once.

Use the copied value as `NORDVPN_ACCESS_TOKEN`. For a non-expiring token, enable MFA on your Nord Account. If a token is exposed or lost, revoke it in Nord Account and generate a new one.

Example with the scheduler:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
  NORDVPN_ACCESS_TOKEN: "your-token"
  COUNTRY_NAME: "Netherlands"
  TOTAL_CONFIGS: "1"
```

The script only removes existing WireGuard `.conf` files after new configs have been fetched and prepared successfully. It installs one active config as `WIREGUARD_CONFIG_FILENAME`, which defaults to `wg0.conf`. Set `WIREGUARD_CONFIG_USE_SOURCE_FILENAME=yes` to keep the generated NordVPN filename instead. If `TOTAL_CONFIGS` is greater than `1`, multiple NordVPN recommendations are fetched and one generated config is selected randomly. If the API call fails, the token is missing, `jq` is unavailable, or no server is returned, the script logs a `[crit]` message and exits without replacing existing configs.

### Bundled Random WireGuard Config Script

The image also includes:

```text
/data/scripts/select_random_wireguard_config.sh
```

This script looks in a configurable source directory, finds all `*.conf` files at that directory level, randomly chooses one, removes existing `*.conf` files from `WIREGUARD_CONFIG_DIR`, and installs the selected config as `wg0.conf` by default.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `WIREGUARD_RANDOM_SOURCE_DIR` | No | `/data/wireguard-configs` | Source directory containing candidate WireGuard `.conf` files. |
| `WIREGUARD_CONFIG_DIR` | No | `/config/wireguard` | Target directory where the selected config is installed. |
| `WIREGUARD_CONFIG_FILENAME` | No | `wg0.conf` | Target filename. Must end with `.conf` and may not contain `/`. |
| `WIREGUARD_CONFIG_USE_SOURCE_FILENAME` | No | `no` | Use `yes` to keep the selected source filename instead of `WIREGUARD_CONFIG_FILENAME`. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/select_random_wireguard_config.sh"
  WIREGUARD_RANDOM_SOURCE_DIR: "/data/wireguard-configs"
  WIREGUARD_CONFIG_DIR: "/config/wireguard"
  WIREGUARD_CONFIG_USE_SOURCE_FILENAME: "no"
```

The script refuses to run if the source and target directories are the same. Existing target configs are deleted only after a readable source config has been selected and copied to a temporary file.

### Bundled Random OpenVPN Config Script

The image also includes:

```text
/data/scripts/select_random_openvpn_config.sh
```

This script follows the OpenVPN behavior of the base image: the base image looks in `/config/openvpn/` for the first `*.ovpn` file and uses that as `VPN_CONFIG`. The script chooses one random `*.ovpn` from a configurable source directory, removes existing target `*.ovpn` files, and installs the selected profile as `openvpn.ovpn` by default.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `OPENVPN_RANDOM_SOURCE_DIR` | No | `/data/openvpn-configs` | Source directory containing candidate OpenVPN `.ovpn` files. |
| `OPENVPN_CONFIG_DIR` | No | `/config/openvpn` | Target directory where the selected profile is installed. |
| `OPENVPN_CONFIG_FILENAME` | No | `openvpn.ovpn` | Target filename. Must end with `.ovpn` and may not contain `/`. |
| `OPENVPN_CONFIG_USE_SOURCE_FILENAME` | No | `no` | Use `yes` to keep the selected source filename instead of `OPENVPN_CONFIG_FILENAME`. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/select_random_openvpn_config.sh"
  OPENVPN_RANDOM_SOURCE_DIR: "/data/openvpn-configs"
  OPENVPN_CONFIG_DIR: "/config/openvpn"
  OPENVPN_CONFIG_USE_SOURCE_FILENAME: "no"
```

The script only copies the selected `.ovpn` file. If your profile references external files such as `ca.crt`, `client.crt`, `client.key`, or an auth file, those files must already be available in `/config/openvpn/`, or the `.ovpn` profile must embed them inline.

### Bundled Config Backup Script

The image also includes:

```text
/data/scripts/backup_config.sh
```

This script creates a timestamped `.tgz` backup of `/config` and stores it in `/data/backups` by default.  
Environment variables for backup scheduling and retention are listed in the **Environment Variables** section under **Scheduled Config Backups**.

### Bundled Log Sanitizer Script

The image also includes:

```text
/data/scripts/log_sanitizer.sh
```

Use this helper before sharing logs externally. It redacts common secrets/tokens, IPv4/IPv6 addresses, and absolute paths.
Run it primarily inside the container where `/data/scripts/log_sanitizer.sh` exists by default. Host-side execution is also possible when `/data` is bind-mounted and this script is available on the host path.

Examples:

```sh
/data/scripts/log_sanitizer.sh /data/nzbgetvpn.log /data/nzbgetvpn.sanitized.log
docker logs nzbgetvpn 2>&1 | /data/scripts/log_sanitizer.sh > /data/nzbgetvpn-dockerlogs.sanitized.log
```

### Bundled Upgrade Check Script

The image also includes:

```text
/data/scripts/upgrade_check.sh
```

Use this helper before updating. It checks local vs remote NZBGetVPN codebase version, compares local NZBGet app version with remote stable/testing metadata, prints pull hints, and shows the relevant changelog impact.
If remote metadata cannot be fetched (for example DNS timeout), it logs warnings and exits successfully after local checks instead of failing hard.

Example:

```sh
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

### Bundled Notification Scripts

The image also includes:

```text
/data/scripts/notify_discord.sh
/data/scripts/notify_telegram.sh
/data/scripts/notify_pushover.sh
```

These scripts send notifications using Discord, Telegram, or Pushover and are safe to use from either:

- `NOTIFY_SELFTEST_STATE_SCRIPT` (state transitions such as `ready -> not_ready`)
- `NOTIFY_UNHEALTHY_SCRIPT` (unhealthy action callbacks)

Shared behavior:

- Optional `NOTIFY_MESSAGE` to override the default generated message.
- When used via `NOTIFY_SELFTEST_STATE_SCRIPT`, they consume:
  - `VPN_SELFTEST_PREVIOUS_STATE`
  - `VPN_SELFTEST_CURRENT_STATE`
  - `VPN_SELFTEST_WARN_COUNT`
  - `VPN_SELFTEST_FAIL_COUNT`

Required service variables:

- Discord: `DISCORD_WEBHOOK_URL`
- Telegram: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
- Pushover: `PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`

Example variables (`notify_discord.sh`):

```yaml
environment:
  DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/..."
  DISCORD_USERNAME: "NZBGetVPN"
  DISCORD_AVATAR_URL: "https://example.com/nzbgetvpn.png"
  DISCORD_MENTIONS: "<@123456789012345678>"
  NOTIFY_MESSAGE: "NZBGetVPN needs attention"
```

Example variables (`notify_telegram.sh`):

```yaml
environment:
  TELEGRAM_BOT_TOKEN: "123456789:your-bot-token"
  TELEGRAM_CHAT_ID: "-1001234567890"
  TELEGRAM_MESSAGE_THREAD_ID: "42"
  TELEGRAM_PARSE_MODE: "Markdown"
  NOTIFY_MESSAGE: "NZBGetVPN needs attention"
```

Example variables (`notify_pushover.sh`):

```yaml
environment:
  PUSHOVER_APP_TOKEN: "your-app-token"
  PUSHOVER_USER_KEY: "your-user-key"
  PUSHOVER_TITLE: "NZBGetVPN"
  PUSHOVER_PRIORITY: "1"
  PUSHOVER_DEVICE: "iphone"
  PUSHOVER_SOUND: "pushover"
  NOTIFY_MESSAGE: "NZBGetVPN needs attention"
```

Example (`NOTIFY_SELFTEST_STATE_SCRIPT` with Discord):

```yaml
environment:
  VPN_SELFTEST_ENABLED: "*/2 * * * *"
  NOTIFY_SELFTEST_STATE_SCRIPT: "/data/scripts/notify_discord.sh"
  DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/..."
```

## Accepted Value Patterns

| Kind | Valid examples | Invalid examples |
| --- | --- | --- |
| Boolean toggle | `yes`, `no` | `true`, `false`, `1`, `0` |
| IPv4 CIDR | `192.168.1.0/24`, `10.0.0.0/8` | `192.168.1.1`, `lan`, `192.168.1.0` |
| CIDR list | `192.168.1.0/24,10.0.0.0/8` | `192.168.1.0/24,` |
| DNS list | `1.1.1.1,1.0.0.1` | `https://1.1.1.1`, `cloudflare` |
| Port | `6789`, `8118`, `51820` | `0`, `65536`, `abc` |
| Port list | `1234,5678` | `1234,`, `abc,5678` |
| Cron schedule | `* * * * *`, `*/15 * * * *`, `0 3 * * *` | `@hourly`, `every 5 minutes` |
| Timeout/cooldown | `60`, `300`, `900` | `0`, `abc` |
| Interface name | `tun0`, `wg0`, `eth0` | `wg 0`, `;rm` |
| UID/GID | `0`, `1000`, `568` | `user`, `abc` |
| UMASK | `000`, `002`, `022`, `0002` | `abc`, `999` |

## Provider Setup

### OpenVPN

1. Start the container once so `/config/openvpn/` is created.
2. Stop the container.
3. Place one `.ovpn` profile and all referenced certificate/key files in `/config/openvpn/`.
4. Start the container again.
5. Watch `docker logs -f nzbgetvpn`.

The base image finds the first `.ovpn` file, converts CRLF line endings, parses the remote server, port, protocol and interface, then starts OpenVPN. If the profile omits a port, the base image defaults to `1194`. If it omits a protocol, it defaults to `udp`.

PIA OpenVPN profiles:

[https://www.privateinternetaccess.com/openvpn/openvpn.zip](https://www.privateinternetaccess.com/openvpn/openvpn.zip)

AirVPN profile generator:

[https://airvpn.org/generator/](https://airvpn.org/generator/)

### WireGuard

WireGuard usually needs:

```yaml
privileged: true
sysctls:
  net.ipv4.conf.all.src_valid_mark: "1"
```

General flow:

1. Start the container once so `/config/wireguard/` is created.
2. Stop the container.
3. Place one WireGuard `.conf` file in `/config/wireguard/`.
4. Start the container again.

The base image finds the first `.conf` file and normalizes it to `/config/wireguard/wg0.conf`. For custom/non-PIA WireGuard setups, the config should contain an `Endpoint = host:port` line. This repo attempts to harden WireGuard config permissions on startup:

```sh
chmod 600 /config/wireguard/*.conf
```

That prevents:

```text
Warning: `/config/wireguard/wg0.conf' is world accessible
```

If your bind mount blocks permission changes, fix the file on the host:

```sh
chmod 600 /path/to/config/wireguard/wg0.conf
```

## Auto-Healing

There are two layers:

| Layer | What it does |
| --- | --- |
| `binhex/arch-int-vpn` | Handles the actual VPN lifecycle. OpenVPN runs in a reconnect loop. WireGuard is checked and cycled when the peer/interface is missing. DNS, port and tunnel failures can trigger the base image to recover the VPN. |
| This repository | Starts and watches NZBGet/Privoxy, waits for NZBGet port `6789`, validates firewall inputs, and optionally runs `VPN_UNHEALTHY_*` or `VPN_CRON_*` scripts. |

If your custom unhealthy script replaces a WireGuard config file, the base image will usually only pick it up after WireGuard is cycled or the container restarts. Use `VPN_UNHEALTHY_ACTION=script+exit` together with `restart: unless-stopped` when you want a clean restart after generating a new config.

## Firewall Behavior

This image applies iptables rules to reduce leakage when the VPN tunnel is down.

Important rules and checks:

| Item | Behavior |
| --- | --- |
| `LAN_NETWORK` | Must be valid IPv4 CIDR. Invalid values stop startup with a `[crit]` message. |
| `VPN_REMOTE_PORT` | Must contain valid ports. It is normally parsed by the base image. |
| `VPN_DEVICE_TYPE` | Must be a valid interface name, for example `tun0` or `wg0`. |
| `ADDITIONAL_PORTS` | Optional compatibility list for extra TCP/UDP ports. Invalid ports stop startup. |
| NZBGet UI | Port `6789/tcp` is allowed from the Docker/LAN side. |
| Privoxy | LAN access is allowed when `ENABLE_PRIVOXY=yes`. |
| Default policy | IPv4/IPv6 input, forward and output default to drop, then explicit allow rules are added. |

## Logging

Supervisor uses `loglevel=info` plus program `stdout_logfile=/dev/fd/1` and `stderr_logfile=/dev/fd/2` so script lines go to Docker logs without debug `DEBG ... stdout output:` wrappers (and without losing output if only log level were lowered). Script output should look like:

```text
[info] Nzbget process started
[info] VPN_CRON_SCHEDULE '*/5 * * * *' matched, running '/data/scripts/get_wireguard_configs_nordvpn.sh'
[warn] VPN IP not detected, VPN tunnel maybe down
[crit] LAN_NETWORK is not set, exiting...
```

After NZBGet is running and listening on port `6789`, startup logs the NZBGetVPN image/codebase version, the NZBGet application version, a link to the GitHub changelog and the maintainer contact page:

```text
[info] NZBGetVPN 4.16.2 | NZBGet 26.1 | Changelog: https://github.com/marc0janssen/nzbgetvpn/blob/develop/CHANGELOG.md | Contact page: https://bio.mjanssen.nl/@Marco
[info] VPN self-test mode 'yes' (VPN_SELFTEST_ENABLED='yes')
[info] VPN self-test watchdog mode 'yes' (VPN_SELFTEST_ENABLED='yes')
[info] Delaying one-shot VPN self-test by 20 seconds after watchdog start (elapsed 0s)
```

Use:

```sh
docker logs -f nzbgetvpn
```

Supervisor can still emit its own lifecycle lines; application script lines are no longer prefixed with debug `stdout output:` events from child log capture.

## Build And Update Workflow

The build scripts are safe by default: without arguments they build the values already pinned in the Dockerfiles.

| Command | Result |
| --- | --- |
| `./build.sh` | Build and push stable using the currently pinned `Dockerfile` values. |
| `./build-testing.sh` | Build and push testing using the currently pinned `Dockerfile-testing` values. |
| `./build.sh 26.2 --sha256 <expected-sha256>` | Update stable NZBGet version, verify the download against the supplied SHA256, update files, then build/push. |
| `./build-testing.sh 26.2-testing-20260510 --sha256 <expected-sha256>` | Update testing NZBGet version, verify the download against the supplied SHA256, update files, then build/push. |
| `./build.sh newest --accept-downloaded-sha256` | Resolve newest stable NZBGet release, explicitly accept the downloaded artifact checksum, update files, then build/push. |
| `./build-testing.sh newest --accept-downloaded-sha256` | Resolve newest testing release asset, explicitly accept the downloaded artifact checksum, update files, then build/push. |
| `./build.sh --base newest` | Resolve newest numeric `binhex/arch-int-vpn` tag, update `Dockerfile`, then build/push. |
| `./build-testing.sh --base newest` | Resolve newest numeric base tag, update `Dockerfile-testing`, then build/push. |
| `./build.sh newest --accept-downloaded-sha256 --base newest` | Update both NZBGet stable and the base image before building. |
| `./build-testing.sh newest --accept-downloaded-sha256 --base newest` | Update both NZBGet testing and the base image before building. |

Both build scripts read the NZBGetVPN codebase version from `VERSION`. Stable builds also push `<nzbget-version>-image-v<version>`, for example `26.1-image-v4.16.2`. Testing builds push the same combined pattern, for example `26.2-testing-20260504-image-v4.16.2`. The same codebase version is also written to the OCI image label `org.opencontainers.image.version`.

When `--base newest` resolves to a different base image tag, `scripts/update-base-image.sh` bumps the patch value in `VERSION` and updates the README version lines before the image build starts. If the Dockerfile is already on the newest resolved base tag, `VERSION` is left unchanged.

When updating NZBGet, prefer `--sha256 <expected-sha256>` using a checksum you verified independently. `--accept-downloaded-sha256` is available for the old trust-on-first-use workflow, but it is intentionally explicit.

Help:

```sh
./build.sh --help
./build-testing.sh --help
```

Direct update scripts live in `scripts/`:

| Script | Purpose |
| --- | --- |
| `scripts/latest-nzbget-version.sh stable` | Print newest stable NZBGet version from GitHub releases. |
| `scripts/latest-nzbget-version.sh testing` | Print newest testing NZBGet version from the `testing` release asset. |
| `scripts/latest-binhex-base-tag.sh` | Print newest numeric `binhex/arch-int-vpn` Docker Hub tag. |
| `scripts/update-stable.sh <version> --sha256 <expected-sha256>` | Update stable Dockerfile/README/SHA256 without building after verifying the download. |
| `scripts/update-testing.sh <version> --sha256 <expected-sha256>` | Update testing Dockerfile/README/SHA256 without building after verifying the download. |
| `scripts/update-base-image.sh <Dockerfile> <tag\|newest>` | Update the base image tag in a Dockerfile. |

## Download Verification And TLS

The Docker build verifies the NZBGet installer before installing it.

| Value | Location | Purpose |
| --- | --- | --- |
| `NZBGET_VERSION` | `Dockerfile`, `Dockerfile-testing` | NZBGet version to install. |
| `NZBGET_VERSION_DIR` | `Dockerfile`, `Dockerfile-testing` | GitHub release directory, for example `v26.1` or `testing`. |
| `NZBGET_SHA256` | `Dockerfile`, `Dockerfile-testing` | Expected SHA256 of the downloaded Linux installer. |

During build, `build/root/install.sh` downloads:

```text
https://github.com/nzbgetcom/nzbget/releases/download/<release-dir>/nzbget-<version>-bin-linux.run
```

Then it verifies the file with:

```sh
sha256sum -c -
```

If the checksum does not match, the build stops.

The update scripts also require an explicit checksum decision before changing Dockerfiles. Use `--sha256 <expected-sha256>` to compare against a value obtained independently, or `--accept-downloaded-sha256` when you intentionally want to pin the checksum calculated from the downloaded artifact.

NZBGet certificate verification uses the Arch Linux system CA bundle:

```text
/etc/ssl/certs/ca-certificates.crt
```

`run/nobody/nzbget.sh` updates `CertStore` in `/config/nzbget.conf` when the system CA bundle is present. This helps with errors such as:

```text
TLS certificate verification failed: unable to get local issuer certificate
```

## Repository Layout

```text
.
|-- Dockerfile
|-- Dockerfile-testing
|-- VERSION
|-- build.sh
|-- build-testing.sh
|-- build/
|   |-- nzbget.conf
|   `-- root/
|       `-- install.sh
|-- run/
|   |-- nobody/
|   |   |-- nzbget.sh
|   |   `-- watchdog.sh
|   `-- root/
|       `-- iptable.sh
`-- scripts/
    |-- latest-binhex-base-tag.sh
    |-- latest-nzbget-version.sh
    |-- update-base-image.sh
    |-- update-stable.sh
    `-- update-testing.sh
```

## Troubleshooting

| Log / symptom | What to check |
| --- | --- |
| `LAN_NETWORK is not set` | Set a valid LAN CIDR, for example `LAN_NETWORK=192.168.1.0/24`. |
| `VPN_REMOTE_PORT is not set` | The base image normally parses this from the VPN config. Check provider/client config and endpoint lines. |
| `Nzbget process started` but port `6789` does not listen | Check `/config/nzbget.conf` and Docker logs. Startup now has a retry limit instead of hanging forever. |
| `wg0.conf is world accessible` | The container tries `chmod 600`. If the warning remains, fix the host-mounted file permissions. |
| `can't find command '/usr/local/bin/shutdown.sh'` | This image installs a fallback script during build; rebuild if you still see this on an old image. |
| `VPN_CRON_SCHEDULE` does not run | Use five cron fields, make the script executable, and prefer Compose mapping form for values with spaces. |
| VPN unhealthy action never runs | Set `VPN_UNHEALTHY_ACTION`, use a positive `VPN_UNHEALTHY_AFTER`, and test with `VPN_UNHEALTHY_TEST=yes`. |
| Container exits but does not come back | Add Docker restart policy, for example `restart: unless-stopped`. A container can exit itself, but Docker must restart it. |

## Notes

DNS providers that support EDNS Client Subnet can expose more client-location metadata. Consider privacy-focused DNS servers instead of Google or OpenDNS if that matters for your setup.

Most VPN mechanics come from `binhex/arch-int-vpn`. This repository intentionally keeps that separation: the base image owns the tunnel, this image owns NZBGet and the extra operational hooks around it.

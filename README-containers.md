# NZBGetVPN

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with OpenVPN, WireGuard, Privoxy, SOCKS support and iptables leak protection.

This image is built on top of [`binhex/arch-int-vpn`](https://github.com/binhex/arch-int-vpn). The base image provides the VPN framework, provider handling, firewall approach and VPN reconnect behavior. This image adds NZBGet, verified NZBGet downloads, readable logging, startup checks, custom VPN unhealthy actions and scheduled VPN scripts.

Full documentation is available in the GitHub repository README.

## Versions

* NZBGetVPN image/codebase version: 4.6.0
* NZBGET Current stable version: 26.1
* NZBGET Current testing version: 26.2-testing-20260506

## Tags

| Tag | Description |
| --- | --- |
| `stable` | Stable NZBGet release. |
| `testing` | Testing NZBGet release. |
| `<version>` | Versioned image, for example `26.1`. |
| `<nzbget-version>-image-v<version>` | Image tagged with both the NZBGet version and the NZBGetVPN codebase version, for example `26.1-image-v4.6.0`. |

## Included

| Component | Port / path |
| --- | --- |
| NZBGet web UI | `6789/tcp` |
| Privoxy | `8118/tcp` when `ENABLE_PRIVOXY=yes` |
| SOCKS proxy | Base-image feature, enabled with `ENABLE_SOCKS=yes` |
| OpenVPN config | `/config/openvpn/` |
| WireGuard config | `/config/wireguard/` |
| NZBGet config | `/config/nzbget.conf` |
| Downloads/data | `/data` |
| Bundled helper scripts | `/data/scripts/` |

## Default Credentials

Default NZBGet login:

```text
username: nzbget
password: tegbzn6789
```

Change this after first start.

Do not expose the web UI directly to the internet without an authenticated reverse proxy or VPN access.

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
  -e PUID=1000 \
  -e PGID=1000 \
  -e UMASK=000 \
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
  -e PUID=1000 \
  -e PGID=1000 \
  -e UMASK=000 \
  marc0janssen/nzbgetvpn:stable
```

Open the UI:

```text
http://<host-ip>:6789
```

Privoxy, when enabled:

```text
http://<host-ip>:8118
```

## Compose

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
      PUID: "1000"
      PGID: "1000"
      UMASK: "000"
    restart: unless-stopped
```

For WireGuard replace `cap_add` with:

```yaml
privileged: true
sysctls:
  net.ipv4.conf.all.src_valid_mark: "1"
```

## Volumes

| Path | Description |
| --- | --- |
| `/config` | Persistent app config, OpenVPN profiles and WireGuard profiles. |
| `/data` | Downloads and optional user scripts. |
| `/etc/localtime:ro` | Recommended for correct log and schedule times. |

On container start, bundled scripts are copied into `/data/scripts/` and updated when the image template differs from the mounted copy. The default source directories `/data/wireguard-configs` and `/data/openvpn-configs` are also created. Each of these `/data` subdirectories gets a small `README.md`. This also works when `/data` is a host bind mount.

## Backup And Restore

Back up `/config` and `/data` together. `/config` contains NZBGet config, OpenVPN profiles and WireGuard profiles. `/data` contains downloads, bundled helper script copies and optional user data.

Example:

```sh
tar -czf nzbgetvpn-backup.tgz /path/to/config /path/to/data
tar -xzf nzbgetvpn-backup.tgz -C /
```

Stop the container first if you need a point-in-time copy. Keep backups private because they may contain VPN profiles, keys, NZBGet credentials or provider tokens.

## Security

Report vulnerabilities privately through the maintainer contact page linked in the repository. Do not put secrets, VPN profiles, keys, tokens or `.env` contents in public issues.

## Important Environment Variables

| Variable | Values | Description |
| --- | --- | --- |
| `VPN_ENABLED` | `yes`, `no` | Enable VPN handling. |
| `VPN_CLIENT` | `openvpn`, `wireguard` | Select VPN client. |
| `VPN_PROV` | `custom`, `pia`, `airvpn`, `nordvpn`, provider-specific | VPN provider used by the base image. |
| `VPN_USER` | string | VPN username, provider-dependent. |
| `VPN_PASS` | string | VPN password, provider-dependent. |
| `LAN_NETWORK` | CIDR list | LAN ranges allowed to access local services, for example `192.168.1.0/24`. |
| `NAME_SERVERS` | IP list | DNS servers used by the VPN framework. |
| `ENABLE_PRIVOXY` | `yes`, `no` | Enable Privoxy on `8118/tcp`. |
| `ENABLE_SOCKS` | `yes`, `no` | Enable inherited SOCKS proxy. |
| `SOCKS_USER` | string | Optional SOCKS auth username. |
| `SOCKS_PASS` | string | Optional SOCKS auth password. |
| `STRICT_PORT_FORWARD` | `yes`, `no` | Base-image port-forward behavior, mainly useful for supported providers. |
| `PUID` / `PGID` | numeric | Runtime file ownership. |
| `UMASK` | octal | File creation mask. |
| `DEBUG` | `true`, `false` | Extra script logging. |
| `VPN_HEALTHCHECK_ENABLED` | `yes`, `no`, boolean | Controls Docker `HEALTHCHECK` probes (`yes` by default). |
| `VPN_SELFTEST_ENABLED` | `no`, `yes`, cron expression | Control internal read-only self-test scheduling (`false`/`0` = `no`, `true`/`1` = `yes`). |
| `VPN_SELFTEST_STARTUP_DELAY` | non-negative integer seconds | Delay one-shot self-test when `VPN_SELFTEST_ENABLED=yes` (default `20`, max `300`). |
| `VPN_SELFTEST_NZBGET_PORT` | TCP port `1-65535` | NZBGet listen port used by self-test checks (`6789` by default). |
| `VPN_SELFTEST_STATE_HOOK` | executable absolute path | Optional script called on readiness transitions (`ready`/`not_ready`). |
| `VPN_SELFTEST_STATE_FILE` | absolute path | File storing previous self-test state (default `/tmp/nzbgetvpn-selftest-state`). |
| `VPN_SELFTEST_STATE_HOOK_TIMEOUT` | positive integer seconds | State-hook timeout (default `30`). |
| `VPN_SELFTEST_STATUS_FILE` | absolute path | Optional JSON status snapshot written atomically after each self-test run. |
| `VPN_SELFTEST_DEBOUNCE_CRIT` | positive integer | Debounce critical failures before switching to `not_ready` and exiting non-zero (default `1`). |
| `VPN_SELFTEST_DEBOUNCE_WARN` | positive integer | When strict mode is enabled, debounce warnings before switching to `not_ready` (default `1`). |
| `VPN_SELFTEST_DEBOUNCE_FILE` | absolute path | Stores consecutive critical/warning streak counters between runs (default `/tmp/nzbgetvpn-selftest-debounce`). |
| `VPN_SELFTEST_READY_FILE` | absolute path | Optional: write `ok <UTC>` on self-test success (atomic); remove file on critical failure. Watchdog also clears stale file on startup before fresh checks. |
| `VPN_SELFTEST_READY_STRICT` | `yes`/`no`/boolean | If truthy, ready file only when zero warnings. |

## VPN Config

OpenVPN:

1. Start the container once so `/config/openvpn/` is created.
2. Stop the container.
3. Put one `.ovpn` file and referenced cert/key files in `/config/openvpn/`.
4. Start the container again.

WireGuard:

1. Start the container once so `/config/wireguard/` is created.
2. Stop the container.
3. Put one `.conf` file in `/config/wireguard/`.
4. Start the container again.

The image tries to set WireGuard config permissions to `600` to avoid `wg0.conf is world accessible` warnings.

## Auto-Healing

Normal VPN recovery comes from `binhex/arch-int-vpn`:

| Client | Behavior |
| --- | --- |
| OpenVPN | Runs in a reconnect loop. |
| WireGuard | The peer/interface is monitored and cycled when needed. |

This image adds app-level fallback actions through `VPN_UNHEALTHY_*`.

## VPN Unhealthy Actions

The watchdog runs every 30 seconds. If the VPN IP is missing for multiple checks, an optional action can be triggered.

| Variable | Default | Description |
| --- | --- | --- |
| `VPN_UNHEALTHY_ACTION` | `none` | `none`, `script`, `script+exit`, or `exit`. |
| `VPN_UNHEALTHY_SCRIPT` | unset | Executable script path for `script` and `script+exit`. |
| `VPN_UNHEALTHY_AFTER` | `10` | Failed checks before action. `10` is about 5 minutes. |
| `VPN_UNHEALTHY_COOLDOWN` | `300` | Minimum seconds between actions. Values below `300` are raised to `300`. |
| `VPN_UNHEALTHY_EXIT_DELAY` | `5` | Delay before exit after a successful script with `script+exit`. |
| `VPN_UNHEALTHY_SCRIPT_TIMEOUT` | `300` | Max runtime for the unhealthy script. |
| `VPN_UNHEALTHY_TEST` | `no` | Set `yes` to simulate a missing VPN IP for testing. |

Example:

```yaml
environment:
  VPN_UNHEALTHY_ACTION: "script+exit"
  VPN_UNHEALTHY_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
  VPN_UNHEALTHY_AFTER: "10"
  VPN_UNHEALTHY_COOLDOWN: "300"
```

Use `restart: unless-stopped` if you want Docker to restart the container after `exit`.

## Scheduled Scripts

Run a custom script from the watchdog with cron-style syntax:

| Variable | Description |
| --- | --- |
| `VPN_CRON_SCHEDULE` | Five-field cron expression, for example `*/5 * * * *`. |
| `VPN_CRON_SCRIPT` | Executable script path. |
| `VPN_CRON_SCRIPT_TIMEOUT` | Max script runtime, default `300`. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
```

Use Compose mapping form for cron schedules because the value contains spaces.

## Internal VPN Self-Test

Internal script path:

```text
/home/nobody/vpn-selftest.sh
```

Enable with:

```yaml
environment:
  VPN_SELFTEST_ENABLED: "yes"
```

Or run periodically:

```yaml
environment:
  VPN_SELFTEST_ENABLED: "*/5 * * * *"
```

The script runs from the watchdog loop, logs to normal container stdout, and does not modify VPN or app state. With `VPN_SELFTEST_ENABLED=yes`, results are a one-shot startup snapshot. With a cron expression, readiness is continuously re-evaluated and the optional ready marker can be updated or removed over time. On container restart, watchdog clears any stale ready marker once before the next self-test cycle. Listen checks target `VPN_SELFTEST_NZBGET_PORT` (default `6789`). Optional `VPN_SELFTEST_STATE_HOOK` runs only when readiness transitions.

## Docker Healthcheck

The image defines a native Docker `HEALTHCHECK` (`interval=60s`, `timeout=30s`, `start-period=120s`, `retries=3`) that runs `/root/healthcheck.sh`. It executes the internal self-test and marks the container unhealthy only for critical failures. Warnings remain healthy. Health probes do not modify ready/state-hook tracking files.

## Bundled NordVPN WireGuard Script

Included script:

```text
/data/scripts/get_wireguard_configs_nordvpn.sh
```

It fetches recommended NordVPN WireGuard servers and writes `.conf` files to `/config/wireguard/`. Existing configs are removed only after new configs are prepared successfully.

| Variable | Default | Description |
| --- | --- | --- |
| `NORDVPN_ACCESS_TOKEN` | required | NordVPN access token. |
| `COUNTRY_NAME` | `Netherlands` | NordVPN country name. |
| `TOTAL_CONFIGS` | `1` | Number of NordVPN recommendations to fetch. If greater than `1`, one generated config is selected randomly. |
| `DNS` | `103.86.96.100` | DNS written to the config. |
| `WIREGUARD_CONFIG_DIR` | `/config/wireguard` | Output directory. |
| `WIREGUARD_CONFIG_FILENAME` | `wg0.conf` | Target filename for the active config. Must end with `.conf` and may not contain `/`. |
| `WIREGUARD_CONFIG_USE_SOURCE_FILENAME` | `no` | Set `yes` to keep the generated NordVPN filename. |
| `WIREGUARD_ADDRESS` | `10.5.0.2/32` | WireGuard interface address. |
| `WIREGUARD_PORT` | `51820` | WireGuard endpoint port. |

Create `NORDVPN_ACCESS_TOKEN` in Nord Account:

1. Log in to `https://my.nordaccount.com/`.
2. Open `NordVPN`.
3. Go to `Advanced settings`.
4. Click `Get access token`.
5. Verify your email address.
6. Generate a temporary or non-expiring token.
7. Copy it immediately; it is only shown once.

Use the copied value as `NORDVPN_ACCESS_TOKEN`. Enable MFA if you use a non-expiring token.

## Bundled Random WireGuard Config Script

Included script:

```text
/data/scripts/select_random_wireguard_config.sh
```

It selects a random `*.conf` from a source directory and installs it as the active WireGuard config.

| Variable | Default | Description |
| --- | --- | --- |
| `WIREGUARD_RANDOM_SOURCE_DIR` | `/data/wireguard-configs` | Source directory containing candidate `.conf` files. |
| `WIREGUARD_CONFIG_DIR` | `/config/wireguard` | Target directory. Existing `*.conf` files are removed after a source config is prepared. |
| `WIREGUARD_CONFIG_FILENAME` | `wg0.conf` | Target filename. |
| `WIREGUARD_CONFIG_USE_SOURCE_FILENAME` | `no` | Set `yes` to keep the selected source filename. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/select_random_wireguard_config.sh"
  WIREGUARD_RANDOM_SOURCE_DIR: "/data/wireguard-configs"
```

## Bundled Random OpenVPN Config Script

Included script:

```text
/data/scripts/select_random_openvpn_config.sh
```

It selects a random `*.ovpn` from a source directory and installs it as the active OpenVPN profile.

| Variable | Default | Description |
| --- | --- | --- |
| `OPENVPN_RANDOM_SOURCE_DIR` | `/data/openvpn-configs` | Source directory containing candidate `.ovpn` files. |
| `OPENVPN_CONFIG_DIR` | `/config/openvpn` | Target directory. Existing `*.ovpn` files are removed after a source profile is prepared. |
| `OPENVPN_CONFIG_FILENAME` | `openvpn.ovpn` | Target filename. |
| `OPENVPN_CONFIG_USE_SOURCE_FILENAME` | `no` | Set `yes` to keep the selected source filename. |

Example:

```yaml
environment:
  VPN_CRON_SCHEDULE: "0 */6 * * *"
  VPN_CRON_SCRIPT: "/data/scripts/select_random_openvpn_config.sh"
  OPENVPN_RANDOM_SOURCE_DIR: "/data/openvpn-configs"
```

If your `.ovpn` references external cert/key/auth files, those files must also be available in `/config/openvpn/`, or the `.ovpn` must embed them inline.

## Build Verification

The Docker build downloads the NZBGet installer from `nzbgetcom/nzbget` and verifies it with the pinned `NZBGET_SHA256` value from the Dockerfile. If the checksum does not match, the build fails. Update scripts require `--sha256 <expected-sha256>` or the explicit `--accept-downloaded-sha256` flag before changing pinned checksums.

After NZBGet is running and listening on port `6789`, startup logs the NZBGetVPN version line and the resolved `VPN_SELFTEST_ENABLED` mode.

NZBGet TLS verification uses the system CA bundle:

```text
/etc/ssl/certs/ca-certificates.crt
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `LAN_NETWORK is not set` | Set a valid CIDR, for example `192.168.1.0/24`. |
| `VPN_REMOTE_PORT is not set` | Check the VPN provider/client config. The base image normally derives this. |
| `wg0.conf is world accessible` | Fix permissions on the host: `chmod 600 wg0.conf`. |
| `VPN_CRON_SCHEDULE` does not run | Use five cron fields and ensure the script is executable. |
| Container exits but does not restart | Add `restart: unless-stopped`. |

## Links

- GitHub: `https://github.com/marc0janssen/nzbgetvpn`
- NZBGet releases: `https://github.com/nzbgetcom/nzbget/releases`
- Base image: `https://github.com/binhex/arch-int-vpn`

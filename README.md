# NZBgetVPN

Docker image for [NZBGet](https://github.com/nzbgetcom/nzbget) with OpenVPN, WireGuard, Privoxy and iptables leak protection.

This repository is a maintained fork-style image build. NZBGet itself is installed from the community-maintained `nzbgetcom/nzbget` releases because the original NZBGet project stopped being maintained.

[Thanks for the tip!](https://ko-fi.com/marc0janssen)

## Versions

[NZBGet release information](https://github.com/nzbgetcom/nzbget/releases)

* NZBGET Current stable version: 26.1
* NZBGET Current testing version: 26.2-testing-20260501

These two lines are intentionally kept in this exact format. The update scripts use them when bumping stable or testing releases.

## What This Image Includes

- NZBGet web UI on port `6789`
- OpenVPN support
- WireGuard support
- Privoxy support on port `8118`
- iptables rules to reduce IP leakage when the VPN tunnel is down
- Config stored under `/config`
- Downloads and NZBGet data stored under `/data`
- Runtime UID/GID support through `PUID` and `PGID`

Default NZBGet login:

- Username: `nzbget`
- Password: `tegbzn6789`

Change these in NZBGet after first start.

## Image Tags

Stable image:

```sh
marc0janssen/nzbgetvpn:stable
```

Testing image:

```sh
marc0janssen/nzbgetvpn:testing
```

Versioned images are also pushed by the build scripts, for example:

```sh
marc0janssen/nzbgetvpn:26.1
marc0janssen/nzbgetvpn:26.2-testing-20260501
```

## Quick Start

OpenVPN example:

```sh
docker run -d \
  --cap-add=NET_ADMIN \
  --name=nzbgetvpn \
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
  -e DEBUG=false \
  -e UMASK=000 \
  -e PUID=1000 \
  -e PGID=1000 \
  marc0janssen/nzbgetvpn:stable
```

WireGuard example:

```sh
docker run -d \
  --privileged=true \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --name=nzbgetvpn \
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
  -e DEBUG=false \
  -e UMASK=000 \
  -e PUID=1000 \
  -e PGID=1000 \
  marc0janssen/nzbgetvpn:stable
```

Access NZBGet at:

```text
http://<host-ip>:6789
```

Access Privoxy, when enabled, at:

```text
http://<host-ip>:8118
```

## Docker Compose

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
      DEBUG: "false"
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

## Volumes

`/config`

Persistent application configuration. This is where OpenVPN and WireGuard configuration files live.

`/data`

NZBGet download directory and application data.

## Environment Variables

The image inherits most VPN behavior from the base VPN image. The table below documents the variables this repo expects, documents, or validates directly. Provider support can change when the base image changes.

### Common Variables

| Variable | Required | Allowed values / format | Example | Description |
| --- | --- | --- | --- | --- |
| `VPN_ENABLED` | Yes | `yes`, `no` | `yes` | Enables VPN handling. Use `no` only if you deliberately want NZBGet without VPN. |
| `VPN_CLIENT` | Yes when VPN is enabled | `openvpn`, `wireguard` | `openvpn` | Selects the VPN client implementation. |
| `VPN_PROV` | Yes when VPN is enabled | `pia`, `airvpn`, `custom`, `nordvpn`, or another provider supported by the base image | `custom` | Provider name consumed by the inherited VPN framework. |
| `LAN_NETWORK` | Yes | IPv4 CIDR, comma-separated for multiple networks | `192.168.1.0/24` | LAN networks allowed to reach the container UI and local services. |
| `NAME_SERVERS` | Recommended | IPv4 addresses, comma-separated | `1.1.1.1,1.0.0.1` | DNS servers used by the VPN framework. |
| `ENABLE_PRIVOXY` | No | `yes`, `no` | `yes` | Enables Privoxy on port `8118`. |
| `STRICT_PORT_FORWARD` | No | `yes`, `no` | `no` | Controls strict provider port-forward behavior where supported. |
| `ADDITIONAL_PORTS` | No | TCP/UDP port numbers `1-65535`, comma-separated | `1234,5678` | Extra ports allowed through the firewall. |
| `DEBUG` | No | `true`, `false` | `false` | Enables more verbose script logging. |
| `UMASK` | No | 3 or 4 digit octal mask | `000`, `002`, `022` | File creation mask inside the container. |
| `PUID` | No | Numeric user ID | `1000` | User ID for runtime file ownership. |
| `PGID` | No | Numeric group ID | `1000` | Group ID for runtime file ownership. |

### VPN Unhealthy Actions

The base VPN image already handles normal OpenVPN and WireGuard reconnects. These variables add an optional application-level fallback in this image: if the VPN remains unhealthy for multiple watchdog checks, run a custom action.

The watchdog runs every 30 seconds.

| Variable | Required | Allowed values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_UNHEALTHY_ACTION` | No | `none`, `script`, `script+exit`, `exit` | `none` | Action to run when VPN health checks keep failing. `none` keeps the default behavior. |
| `VPN_UNHEALTHY_SCRIPT` | For `script` and `script+exit` | Executable path inside the container | unset | Script to run when `VPN_UNHEALTHY_ACTION=script` or `script+exit`. Example: `/config/scripts/vpn-unhealthy.sh`. |
| `VPN_UNHEALTHY_AFTER` | No | Positive integer | `10` | Number of failed watchdog checks before triggering the action. With the 30 second watchdog interval, `10` is about 5 minutes. |
| `VPN_UNHEALTHY_COOLDOWN` | No | Positive integer seconds, minimum `300` | `300` | Minimum seconds between repeated actions. Values below `300` are ignored and logged; the script uses `300` instead. |
| `VPN_UNHEALTHY_EXIT_DELAY` | No | Positive integer seconds | `5` | Delay before exiting when `VPN_UNHEALTHY_ACTION=script+exit`. The exit only happens after the script finishes successfully. |
| `VPN_UNHEALTHY_TEST` | No | `yes`, `no` | `no` | Testing switch. When set to `yes`, the watchdog pretends the VPN IP is missing so you can test unhealthy actions. |
| `VPN_UNHEALTHY_SCRIPT_TIMEOUT` | No | Positive integer seconds | `300` | Maximum runtime for `VPN_UNHEALTHY_SCRIPT`. If the script exceeds this, it is stopped and logged as failed. |

Example:

```sh
-e VPN_UNHEALTHY_ACTION=script \
-e VPN_UNHEALTHY_SCRIPT=/config/scripts/vpn-unhealthy.sh \
-e VPN_UNHEALTHY_AFTER=10 \
-e VPN_UNHEALTHY_COOLDOWN=300
```

The custom script receives `VPN_UNHEALTHY_COUNT` in its environment.

Use `script+exit` when Docker should restart the container after your custom script finishes:

```sh
-e VPN_UNHEALTHY_ACTION=script+exit \
-e VPN_UNHEALTHY_SCRIPT=/config/scripts/vpn-unhealthy.sh \
-e VPN_UNHEALTHY_EXIT_DELAY=5
```

For `script+exit` to restart the container, start it with a Docker restart policy such as `--restart unless-stopped` or `restart: unless-stopped` in Compose.

To test your unhealthy action without breaking the real VPN connection:

```sh
-e VPN_UNHEALTHY_TEST=yes \
-e VPN_UNHEALTHY_AFTER=1
```

Remove `VPN_UNHEALTHY_TEST=yes` after testing. If you combine it with `script+exit` and a Docker restart policy, the container can intentionally restart in a loop until the test flag is removed.

### Scheduled VPN Scripts

You can run a custom script on a cron-style schedule from the existing watchdog loop. This does not start a separate cron daemon.

| Variable | Required | Allowed values / format | Default | Description |
| --- | --- | --- | --- | --- |
| `VPN_CRON_SCHEDULE` | With `VPN_CRON_SCRIPT` | Five-field cron expression | unset | Schedule for the custom script. Supports `*`, lists, ranges and steps such as `*/5 * * * *`. |
| `VPN_CRON_SCRIPT` | With `VPN_CRON_SCHEDULE` | Executable path inside the container | unset | Script to run when the schedule matches. Example: `/config/scripts/vpn-cron.sh`. |
| `VPN_CRON_SCRIPT_TIMEOUT` | No | Positive integer seconds | `300` | Maximum runtime for `VPN_CRON_SCRIPT`. If the script exceeds this, it is stopped and logged as failed. |

Example:

```sh
-e VPN_CRON_SCHEDULE="*/15 * * * *" \
-e VPN_CRON_SCRIPT=/config/scripts/vpn-cron.sh
```

Docker Compose mapping form is recommended:

```yaml
environment:
  VPN_CRON_SCHEDULE: "*/5 * * * *"
  VPN_CRON_SCRIPT: "/data/scripts/get_wireguard_configs_nordvpn.sh"
```

If you use Compose list form, do not put quotes after `=`:

```yaml
environment:
  - VPN_CRON_SCHEDULE=*/5 * * * *
  - VPN_CRON_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
```

The watchdog checks the schedule every 30 seconds, before the blocking VPN health checks run, but a matching cron minute runs only once. The script receives `VPN_CRON_SCHEDULE` in its environment.

### Provider Credentials And OpenVPN Options

| Variable | Required | Allowed values / format | Example | Description |
| --- | --- | --- | --- | --- |
| `VPN_USER` | Provider-dependent | String | `my-user` | VPN username. Usually needed for providers such as PIA with username/password authentication. |
| `VPN_PASS` | Provider-dependent | String | `my-password` | VPN password. |
| `VPN_OPTIONS` | No | OpenVPN command-line options | `--pull-filter ignore redirect-gateway` | Extra options passed to OpenVPN. Only relevant for `VPN_CLIENT=openvpn`. |
| `VPN_REMOTE` | Provider-dependent | Hostname or IP, sometimes comma-separated | `nl.example.vpn` | Optional remote endpoint override for providers that support it. |

### Firewall And VPN Internals

Most users do not need to set these directly. They are normally created by the inherited VPN framework, but they are documented because this repo validates or uses them in `run/root/iptable.sh`.

| Variable | Usually set by | Allowed values / format | Example | Description |
| --- | --- | --- | --- | --- |
| `VPN_REMOTE_PORT` | VPN framework | Port numbers `1-65535`, comma-separated | `1198`, `51820` | Remote VPN endpoint ports allowed outside the tunnel. Startup stops if this is missing or invalid while firewall setup runs. |
| `VPN_DEVICE_TYPE` | VPN framework | Linux interface name | `tun0`, `wg0` | VPN tunnel interface used for leak-protection iptables rules. |

### Accepted Value Patterns

| Kind | Format | Valid examples | Invalid examples |
| --- | --- | --- | --- |
| Boolean VPN toggles | `yes` or `no` | `yes`, `no` | `true`, `1`, `on` |
| Debug toggle | `true` or `false` | `true`, `false` | `yes`, `1`, `on` |
| IPv4 CIDR | `a.b.c.d/prefix` | `192.168.1.0/24`, `10.0.0.0/8` | `192.168.1.1`, `lan`, `192.168.1.0` |
| CIDR list | comma-separated IPv4 CIDRs | `192.168.1.0/24,10.0.0.0/8` | `192.168.1.0/24,` |
| DNS list | comma-separated IPv4 addresses | `1.1.1.1,1.0.0.1` | `https://1.1.1.1`, `cloudflare` |
| Port | integer `1-65535` | `6789`, `8118`, `51820` | `0`, `65536`, `abc` |
| Port list | comma-separated ports | `1234,5678` | `1234,`, `abc,5678` |
| Cron schedule | five cron fields | `* * * * *`, `*/15 * * * *`, `0 3 * * *` | `@hourly`, `every 5 minutes` |
| Timeout seconds | positive integer seconds | `60`, `300`, `900` | `0`, `abc` |
| Cooldown seconds | integer, minimum `300` for `VPN_UNHEALTHY_COOLDOWN` | `300`, `900` | `0`, `60`, `abc` |
| Interface | letters, numbers, `_`, `.`, `:`, `-` | `tun0`, `wg0`, `eth0` | `wg 0`, `;rm` |
| UID/GID | numeric ID | `0`, `1000`, `568` | `user`, `abc` |
| UMASK | octal mask | `000`, `002`, `022`, `0002` | `abc`, `999` |

### Provider Examples

| Provider | `VPN_PROV` | Typical `VPN_CLIENT` | Usually needs `VPN_USER` / `VPN_PASS` | Config files |
| --- | --- | --- | --- | --- |
| Custom OpenVPN provider | `custom` | `openvpn` | Depends on provider | Put one `.ovpn` profile in `/config/openvpn/`. |
| Custom WireGuard provider | `custom` | `wireguard` | Usually no | Put `wg0.conf` in `/config/wireguard/`. |
| Private Internet Access | `pia` | `openvpn` or `wireguard` | Yes for OpenVPN | OpenVPN profiles can be downloaded from PIA. WireGuard may be generated by the base image where supported. |
| AirVPN | `airvpn` | `openvpn` | Usually profile/cert based | Generate a Linux OpenVPN profile from AirVPN and place it in `/config/openvpn/`. |
| NordVPN | `nordvpn` | `wireguard` or `openvpn` | Provider/base-image dependent | Support depends on the inherited base image behavior. |

Find your user and group IDs with:

```sh
id <username>
```

## OpenVPN Setup

This image does not include provider-specific OpenVPN profiles or certificates.

General flow:

1. Start the container once so `/config` folders are created.
2. Stop the container.
3. Place one `.ovpn` profile plus its referenced certificate files in `/config/openvpn/`.
4. Start the container again.
5. Check Docker logs for VPN connection status.

PIA users can download OpenVPN profiles from:

[https://www.privateinternetaccess.com/openvpn/openvpn.zip](https://www.privateinternetaccess.com/openvpn/openvpn.zip)

AirVPN users should generate a Linux profile from:

[https://airvpn.org/generator/](https://airvpn.org/generator/)

If a provider zip contains multiple `.ovpn` files, keep only the endpoint you want to use unless the base image documentation for that provider says otherwise.

## WireGuard Setup

WireGuard usually requires:

```sh
--privileged=true
--sysctl="net.ipv4.conf.all.src_valid_mark=1"
```

General flow:

1. Start the container once so `/config/wireguard/` is created.
2. Stop the container.
3. Place your WireGuard config at `/config/wireguard/wg0.conf`.
4. Start the container again.

At startup the container attempts to harden WireGuard config permissions:

```sh
chmod 600 /config/wireguard/*.conf
```

This prevents warnings such as:

```text
Warning: `/config/wireguard/wg0.conf' is world accessible
```

If your host mount prevents permission changes, fix it on the host:

```sh
chmod 600 /path/to/config/wireguard/wg0.conf
```

## Firewall Behavior

The image applies iptables rules to limit traffic leakage when the VPN tunnel is down.

Important details:

- `LAN_NETWORK` must be a valid IPv4 CIDR, for example `192.168.1.0/24`.
- `VPN_REMOTE_PORT` must contain valid ports.
- `ADDITIONAL_PORTS`, when set, must contain valid ports.
- `VPN_DEVICE_TYPE` must be a valid interface name.
- Invalid firewall input now stops startup with a clear `[crit]` log line.

The NZBGet web UI port `6789` is allowed on the Docker/LAN side. Tunnel traffic is allowed through the VPN interface.

## Logging

The supervisor config sends script stdout and stderr directly to Docker logs. This keeps logs readable:

```text
[info] Nzbget process started
[warn] VPN IP not detected, VPN tunnel maybe down
[crit] LAN_NETWORK is not set, exiting...
```

Supervisor may still emit its own lifecycle messages, but script output should no longer be wrapped in noisy `DEBG 'start-script' stdout output` prefixes.

Use:

```sh
docker logs -f nzbgetvpn
```

## Building The Image

Build stable with the currently pinned values from `Dockerfile`:

```sh
./build.sh
```

Build testing with the currently pinned values from `Dockerfile-testing`:

```sh
./build-testing.sh
```

Show help:

```sh
./build.sh --help
./build-testing.sh --help
```

Look up the newest upstream version before building:

```sh
./build.sh newest
./build-testing.sh newest
```

Look up and pin the newest `binhex/arch-int-vpn` base image tag before building:

```sh
./build.sh --base newest
./build-testing.sh --base newest
```

You can combine both lookups:

```sh
./build.sh newest --base newest
./build-testing.sh newest --base newest
```

Normal builds without arguments do not call GitHub or Docker Hub and keep using the pinned values from the Dockerfiles.

## Updating NZBGet Versions

Stable release update:

```sh
./build.sh 26.2
```

This runs:

```sh
./scripts/update-stable.sh 26.2
```

The update script:

- downloads the selected NZBGet release asset;
- calculates its SHA256 hash;
- updates `Dockerfile`;
- updates the stable version line in this README;
- then `build.sh` builds and pushes the image.

To ask GitHub for the newest stable release automatically:

```sh
./build.sh newest
```

This resolves the latest stable release from `nzbgetcom/nzbget`, then runs the same update/build flow.

Base image update:

```sh
./build.sh --base 2026032801
./build-testing.sh --base newest
```

This updates the `FROM binhex/arch-int-vpn:<tag>` line in the relevant Dockerfile before building. Use `newest` to query Docker Hub for the newest numeric `binhex/arch-int-vpn` tag.

Testing release update:

```sh
./build-testing.sh 26.2-testing-20260510
```

This runs:

```sh
./scripts/update-testing.sh 26.2-testing-20260510
```

The testing update script updates `Dockerfile-testing` and the testing version line in this README.

To ask GitHub for the newest testing build automatically:

```sh
./build-testing.sh newest
```

This reads the `testing` release assets from `nzbgetcom/nzbget` and extracts the `nzbget-*-bin-linux.run` version.

You can also run the update scripts directly if you only want to update files without building:

```sh
./scripts/update-stable.sh 26.2
./scripts/update-testing.sh 26.2-testing-20260510
```

Without an argument, the update scripts refresh hashes for the version already pinned in the relevant Dockerfile.

## Download Verification

The Docker build verifies downloaded files before installing them.

`Dockerfile` and `Dockerfile-testing` contain:

- `NZBGET_SHA256`

During build, `build/root/install.sh` downloads the NZBGet installer and validates it with `sha256sum -c -`.

If a hash does not match, the build stops. This is intentional.

NZBGet certificate verification uses the system CA bundle from Arch:

```text
/etc/ssl/certs/ca-certificates.crt
```

That avoids relying on a separate vendored NZBGet `cacert.pem` file and keeps certificate issuers updated through the distro `ca-certificates` package.

## Repository Layout

```text
.
|-- Dockerfile
|-- Dockerfile-testing
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

`LAN_NETWORK is not set`

Set a valid LAN CIDR:

```sh
-e LAN_NETWORK=192.168.1.0/24
```

`VPN_REMOTE_PORT is not set`

The inherited VPN framework normally provides this. If you see this after a base image change, check the provider/client configuration and generated VPN env vars.

`Nzbget process started` but port `6789` does not listen

The startup script now waits with a retry limit instead of hanging forever. Check `/config/nzbget.conf` and Docker logs for NZBGet startup errors.

`Warning: wg0.conf is world accessible`

The container tries to fix this automatically with `chmod 600`. If the warning remains, fix permissions on the host-mounted file.

`can't find command '/usr/local/bin/shutdown.sh'`

The image installs a fallback shutdown script during build if the base image does not provide one.

## Notes

DNS providers that support EDNS Client Subnet can expose more client-location metadata. Consider privacy-focused DNS servers instead of Google or OpenDNS if that matters for your setup.

The original VPN container framework and much of the surrounding approach comes from binhex-style VPN containers. If you appreciate that work, please consider supporting the original maintainers too.

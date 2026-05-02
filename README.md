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

| Variable | Required | Example | Description |
| --- | --- | --- | --- |
| `VPN_ENABLED` | Yes | `yes` | Enables VPN handling. Use `no` only if you deliberately want NZBGet without VPN. |
| `VPN_CLIENT` | Yes when VPN is enabled | `openvpn` or `wireguard` | Selects VPN client. |
| `VPN_PROV` | Yes when VPN is enabled | `pia`, `airvpn`, `custom`, `nordvpn` | Provider name consumed by the inherited VPN framework. Provider support depends on the base image. |
| `VPN_USER` | Provider-dependent | `username` | VPN username, mainly for providers that support auth-based OpenVPN setup. |
| `VPN_PASS` | Provider-dependent | `password` | VPN password. |
| `VPN_OPTIONS` | No | `--pull-filter ignore redirect-gateway` | Extra OpenVPN CLI options. |
| `STRICT_PORT_FORWARD` | No | `yes` or `no` | Controls strict provider port-forward behavior where supported. |
| `ENABLE_PRIVOXY` | No | `yes` | Enables Privoxy on port `8118`. |
| `LAN_NETWORK` | Yes | `192.168.1.0/24` | LAN networks allowed to reach the container UI. Multiple values can be comma-separated. |
| `NAME_SERVERS` | Recommended | `1.1.1.1,1.0.0.1` | DNS servers used by the VPN framework. |
| `ADDITIONAL_PORTS` | No | `1234,5678` | Extra ports allowed through the firewall. |
| `DEBUG` | No | `false` | Set to `true` for more verbose logging. |
| `UMASK` | No | `000` | File creation mask inside the container. |
| `PUID` | No | `1000` | User ID for runtime file ownership. |
| `PGID` | No | `1000` | Group ID for runtime file ownership. |

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
- downloads the NZBGet CA certificate store;
- calculates its SHA256 hash;
- updates `Dockerfile`;
- updates the stable version line in this README;
- then `build.sh` builds and pushes the image.

Testing release update:

```sh
./build-testing.sh 26.2-testing-20260510
```

This runs:

```sh
./scripts/update-testing.sh 26.2-testing-20260510
```

The testing update script updates `Dockerfile-testing` and the testing version line in this README.

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
- `NZBGET_CACERT_SHA256`

During build, `build/root/install.sh` downloads the NZBGet installer and CA certificate file, then validates both with `sha256sum -c -`.

If a hash does not match, the build stops. This is intentional.

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

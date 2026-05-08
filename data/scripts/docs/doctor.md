# doctor.sh

Runs quick local diagnostics for common NZBGetVPN runtime/configuration issues.

## Usage

Manual:

```sh
/data/scripts/doctor.sh
```

Run it from unhealthy or cron hooks when you want extra diagnostics in logs:

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/doctor.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=60
```

## Checks Performed

- Required command availability (`awk`, `curl`)
- Optional command availability (`ip`) for route/interface checks
- Read/write access for `/data` and `/config`
- Default route presence
- Presence and format sanity of DNS nameserver entries in `/etc/resolv.conf`
- VPN interface and IP signal checks when VPN is enabled (`VPN_DEVICE_TYPE`, `VPN_IP`/interface IPv4)
- VPN profile availability for selected `VPN_CLIENT`:
  - OpenVPN: at least one `/config/openvpn/*.ovpn`
  - WireGuard: at least one `/config/wireguard/*.conf`
- Optional internet reachability probe (warning-only) via configurable URL and timeout

Exit status is `0` when no critical issues are found and `1` when one or more critical checks fail.

## Optional Variables

```text
DOCTOR_DATA_DIR=/data
DOCTOR_CONFIG_DIR=/config
DOCTOR_OPENVPN_DIR=/config/openvpn
DOCTOR_WIREGUARD_DIR=/config/wireguard
DOCTOR_INTERNET_CHECK_ENABLED=no
DOCTOR_INTERNET_CHECK_TIMEOUT=5
DOCTOR_INTERNET_CHECK_URL=https://1.1.1.1
```

These overrides are mainly useful for local dry-runs or custom layouts.

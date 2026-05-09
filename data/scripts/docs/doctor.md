# doctor.sh

Runs quick local diagnostics for common NZBGetVPN runtime/configuration issues.

## Usage

Manual:

```sh
/data/scripts/doctor.sh
```

Heal managed bundled templates first, then run checks:

```sh
/data/scripts/container/doctor.sh --heal
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

When `--heal` is used, `doctor.sh` force-resyncs managed bundled templates from image copies into `/data` before running diagnostics. Replaced files are backed up under `/data/backups/doctor-heal-<timestamp>/`.

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

## Interpreting Common Warnings

If you see:

- `[info] [doctor] Internet reachability check disabled`
- `[warn] [doctor] WARN: VPN_DEVICE_TYPE is not set; skipping VPN interface check`

this usually means `doctor.sh` is running with default conservative settings or before VPN startup is fully initialized.

### Enable internet reachability check

By default `DOCTOR_INTERNET_CHECK_ENABLED=no`, so this check is disabled unless you opt in.

```sh
DOCTOR_INTERNET_CHECK_ENABLED=yes /data/scripts/container/doctor.sh
```

Optionally tune:

```sh
DOCTOR_INTERNET_CHECK_ENABLED=yes \
DOCTOR_INTERNET_CHECK_TIMEOUT=10 \
DOCTOR_INTERNET_CHECK_URL=https://1.1.1.1 \
/data/scripts/container/doctor.sh
```

### Enable VPN interface validation

The VPN interface check requires `VPN_DEVICE_TYPE` (for example `tun0` or `wg0`).

To verify manually:

```sh
VPN_DEVICE_TYPE=tun0 /data/scripts/container/doctor.sh
```

or for WireGuard:

```sh
VPN_DEVICE_TYPE=wg0 /data/scripts/container/doctor.sh
```

If you run `doctor.sh` very early during startup, rerun it after VPN initialization so `VPN_DEVICE_TYPE` and interface state are available.

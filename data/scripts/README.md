# NZBGetVPN Helper Scripts

This directory contains helper scripts that can be run manually, with `VPN_CRON_SCRIPT`, or with `VPN_UNHEALTHY_SCRIPT`.

Bundled scripts are managed by the image. On container start, they are installed or updated from the image templates. Put your own custom scripts under a different filename.

Bundled scripts:

| Script | Purpose |
| --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Fetch NordVPN WireGuard recommendations and install one active WireGuard config. |
| `select_random_wireguard_config.sh` | Pick a random `*.conf` from `/data/wireguard-configs` and install it in `/config/wireguard`. |
| `select_random_openvpn_config.sh` | Pick a random `*.ovpn` from `/data/openvpn-configs` and install it in `/config/openvpn`. |

## NordVPN Access Token

`get_wireguard_configs_nordvpn.sh` needs `NORDVPN_ACCESS_TOKEN`.

Create it in Nord Account:

1. Log in to `https://my.nordaccount.com/`.
2. Open `NordVPN`.
3. Go to `Advanced settings`.
4. Click `Get access token`.
5. Verify your email address.
6. Generate a temporary or non-expiring token.
7. Copy it immediately; it is only shown once.

Use the copied value as:

```text
NORDVPN_ACCESS_TOKEN=your-token
```

Enable MFA if you use a non-expiring token. Revoke exposed or lost tokens in Nord Account.

Example scheduler usage:

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_wireguard_config.sh
```

Example unhealthy action usage:

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
```

Make sure custom scripts are executable:

```text
chmod +x /data/scripts/my-script.sh
```

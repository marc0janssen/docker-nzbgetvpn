# get_wireguard_configs_nordvpn.sh

Fetches NordVPN WireGuard recommendations and installs one active config in `/config/wireguard`.

## Required

```text
NORDVPN_ACCESS_TOKEN=your-token
```

## Common Variables

```text
COUNTRY_NAME=Netherlands
TOTAL_CONFIGS=1
DNS=103.86.96.100
WIREGUARD_CONFIG_DIR=/config/wireguard
WIREGUARD_CONFIG_FILENAME=wg0.conf
WIREGUARD_CONFIG_USE_SOURCE_FILENAME=no
WIREGUARD_ADDRESS=10.5.0.2/32
WIREGUARD_PORT=51820
```

## Usage

Manual:

```sh
/data/scripts/get_wireguard_configs_nordvpn.sh
```

Cron:

```text
VPN_CRON_SCHEDULE=0 */6 * * *
VPN_CRON_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

Unhealthy:

```text
VPN_UNHEALTHY_ACTION=script+exit
VPN_UNHEALTHY_SCRIPT=/data/scripts/get_wireguard_configs_nordvpn.sh
VPN_UNHEALTHY_SCRIPT_TIMEOUT=300
```

# select_random_wireguard_config.sh

Selects one random WireGuard profile from a source directory and installs it as active config.

## Common Variables

```text
WIREGUARD_RANDOM_SOURCE_DIR=/data/wireguard-configs
WIREGUARD_CONFIG_DIR=/config/wireguard
WIREGUARD_CONFIG_FILENAME=wg0.conf
WIREGUARD_CONFIG_USE_SOURCE_FILENAME=no
```

## Usage

Manual:

```sh
/data/scripts/select_random_wireguard_config.sh
```

Scheduled:

```text
VPN_CRON_SCHEDULE=0 */12 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_wireguard_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

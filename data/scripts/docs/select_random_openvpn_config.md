# select_random_openvpn_config.sh

Selects one random OpenVPN profile from a source directory and installs it as active config.

## Common Variables

```text
OPENVPN_RANDOM_SOURCE_DIR=/data/openvpn-configs
OPENVPN_CONFIG_DIR=/config/openvpn
OPENVPN_CONFIG_FILENAME=openvpn.ovpn
OPENVPN_CONFIG_USE_SOURCE_FILENAME=no
```

If the selected `.ovpn` references external cert/key/auth files, those files must also be available in `/config/openvpn/` (or embedded inline).

## Usage

Manual:

```sh
/data/scripts/select_random_openvpn_config.sh
```

Scheduled:

```text
VPN_CRON_SCHEDULE=30 */12 * * *
VPN_CRON_SCRIPT=/data/scripts/select_random_openvpn_config.sh
VPN_CRON_SCRIPT_TIMEOUT=300
```

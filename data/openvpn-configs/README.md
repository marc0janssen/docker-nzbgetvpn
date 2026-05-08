# OpenVPN Config Source Directory

Put OpenVPN `*.ovpn` files in this directory when you want NZBGetVPN to choose one for `/config/openvpn`.

Use this bundled script:

```text
/data/scripts/container/select_random_openvpn_config.sh
```

Common environment variables:

```text
OPENVPN_RANDOM_SOURCE_DIR=/data/openvpn-configs
OPENVPN_CONFIG_DIR=/config/openvpn
OPENVPN_CONFIG_FILENAME=openvpn.ovpn
OPENVPN_CONFIG_USE_SOURCE_FILENAME=no
```

The script randomly selects one `*.ovpn`, removes old target `*.ovpn` files from `/config/openvpn`, and installs the selected profile.

If your `.ovpn` references external files such as `ca.crt`, `client.key`, or auth files, those files must also be available in `/config/openvpn`, or embedded inline in the `.ovpn`.

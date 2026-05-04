# WireGuard Config Source Directory

Put WireGuard `*.conf` files in this directory when you want NZBGetVPN to choose one for `/config/wireguard`.

Use this bundled script:

```text
/data/scripts/select_random_wireguard_config.sh
```

Common environment variables:

```text
WIREGUARD_RANDOM_SOURCE_DIR=/data/wireguard-configs
WIREGUARD_CONFIG_DIR=/config/wireguard
WIREGUARD_CONFIG_FILENAME=wg0.conf
WIREGUARD_CONFIG_USE_SOURCE_FILENAME=no
```

The script randomly selects one `*.conf`, removes old target `*.conf` files from `/config/wireguard`, and installs the selected config.

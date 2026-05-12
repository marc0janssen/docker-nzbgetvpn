# NZBGetVPN Compose Examples

These examples are a small golden path for local Docker Compose setups.

## Stable

```sh
docker compose -f examples/docker-compose.yml up -d
```

The stable example stores persistent container state in:

| Host path | Container path | Purpose |
| --- | --- | --- |
| `examples/config` | `/config` | NZBGet config, OpenVPN profiles and WireGuard profiles. |
| `examples/data` | `/data` | Downloads, bundled helper scripts and optional user data. |

Edit `LAN_NETWORK`, `PUID` and `PGID` before first start. For OpenVPN, place one `.ovpn` profile and any referenced cert/key files under `examples/config/openvpn/`. For WireGuard, switch `VPN_CLIENT` to `wireguard`, use the WireGuard settings shown in the compose comments, and place one `.conf` file under `examples/config/wireguard/`.

## Testing Image

```sh
docker compose -f examples/docker-compose.testing.yml up -d
```

The testing example is now a complete standalone compose file (same defaults as the stable example, but with `marc0janssen/nzbgetvpn:testing`).

## Secrets

Do not commit provider credentials, VPN profiles, private keys, tokens or `.env` files. Put credentials in a local untracked `examples/.env` file, Docker secrets, or your orchestrator's secret store. Docker Compose reads `examples/.env` automatically when using these files. The example `.gitignore` excludes local `config`, `data` and `.env` files.

See the main [README](../index.md) for all environment variables, provider notes, bundled scripts and troubleshooting.

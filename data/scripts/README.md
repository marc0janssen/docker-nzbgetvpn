# NZBGetVPN Helper Scripts

This directory contains helper scripts that can be run manually, with `VPN_CRON_SCRIPT`, or with `VPN_UNHEALTHY_SCRIPT`.

Bundled scripts are managed by the image. On container start, they are installed or updated from the image templates. Put your own custom scripts under a different filename.

Bundled scripts:

| Script | Purpose |
| --- | --- |
| `get_wireguard_configs_nordvpn.sh` | Fetch NordVPN WireGuard recommendations and install one active WireGuard config. |
| `select_random_wireguard_config.sh` | Pick a random `*.conf` from `/data/wireguard-configs` and install it in `/config/wireguard`. |
| `select_random_openvpn_config.sh` | Pick a random `*.ovpn` from `/data/openvpn-configs` and install it in `/config/openvpn`. |
| `notify_discord.sh` | Send a state/unhealthy notification to a Discord webhook. |
| `notify_telegram.sh` | Send a state/unhealthy notification through the Telegram Bot API. |
| `notify_pushover.sh` | Send a state/unhealthy notification through Pushover. |

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

Example self-test transition hook usage:

```text
VPN_SELFTEST_ENABLED=*/2 * * * *
VPN_SELFTEST_STATE_HOOK=/data/scripts/notify_discord.sh
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Notification helper scripts support:

- `NOTIFY_MESSAGE` (optional custom message override)
- Self-test state context from `VPN_SELFTEST_STATE_HOOK`:
  - `VPN_SELFTEST_PREVIOUS_STATE`
  - `VPN_SELFTEST_CURRENT_STATE`
  - `VPN_SELFTEST_WARN_COUNT`
  - `VPN_SELFTEST_FAIL_COUNT`

Service-specific variables:

- `notify_discord.sh`
  - required: `DISCORD_WEBHOOK_URL`
  - optional: `DISCORD_USERNAME`, `DISCORD_AVATAR_URL`, `DISCORD_MENTIONS`
- `notify_telegram.sh`
  - required: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
  - optional: `TELEGRAM_MESSAGE_THREAD_ID`, `TELEGRAM_PARSE_MODE`
- `notify_pushover.sh`
  - required: `PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`
  - optional: `PUSHOVER_TITLE`, `PUSHOVER_PRIORITY`, `PUSHOVER_DEVICE`, `PUSHOVER_SOUND`

Make sure custom scripts are executable:

```text
chmod +x /data/scripts/my-script.sh
```

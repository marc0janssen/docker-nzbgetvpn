# Notification Scripts

Notification helpers:

- `notify_discord.sh`
- `notify_telegram.sh`
- `notify_pushover.sh`

They can be used by:

- `NOTIFY_SELFTEST_STATE_SCRIPT`
- `NOTIFY_UNHEALTHY_SCRIPT`

Optional shared override:

```text
NOTIFY_MESSAGE=Custom message
```

Self-test transition context variables:

```text
VPN_SELFTEST_PREVIOUS_STATE
VPN_SELFTEST_CURRENT_STATE
VPN_SELFTEST_WARN_COUNT
VPN_SELFTEST_FAIL_COUNT
```

## Discord

Required:

```text
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

## Telegram

Required:

```text
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_CHAT_ID=-1001234567890
```

## Pushover

Required:

```text
PUSHOVER_APP_TOKEN=your-app-token
PUSHOVER_USER_KEY=your-user-key
```

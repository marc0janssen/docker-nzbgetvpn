# rotate_on_poor_speed.sh

Measures endpoint quality and rotates VPN profiles when poor performance persists for a configured streak.

## Common Variables

Defaults below are generated from the shared runtime defaults in `data/scripts/lib.sh`.

<!-- BEGIN ROTATE_DEFAULTS -->

```text
ROTATE_MODE=auto
ROTATE_SPEEDTEST_URLS=https://proof.ovh.net/files/10Mb.dat,https://download-installer.cdn.mozilla.net/pub/firefox/releases/138.0/linux-x86_64/en-US/firefox-138.0.tar.xz
ROTATE_SPEEDTEST_WEIGHTS=0.60,0.40
ROTATE_SPEEDTEST_TIMEOUT=20
ROTATE_SPEEDTEST_ATTEMPTS=1
ROTATE_MIN_SUCCESSFUL_ENDPOINTS=1
ROTATE_MIN_DOWNLOAD_MBPS=10
ROTATE_MAX_LATENCY_MS=700
ROTATE_FAIL_STREAK=3
ROTATE_COOLDOWN_SECONDS=1800
ROTATE_POST_ROTATION_ACTION=none
ROTATE_ON_POOR_SPEED_ENABLED=yes
ROTATE_ON_POOR_SPEED_SCHEDULE=*/20 * * * *
ROTATE_ON_POOR_SPEED_SCRIPT=/data/scripts/container/rotate_on_poor_speed.sh
ROTATE_ON_POOR_SPEED_TIMEOUT=90
```
<!-- END ROTATE_DEFAULTS -->

Use `restart: unless-stopped` when `ROTATE_POST_ROTATION_ACTION=watchdog-exit`.

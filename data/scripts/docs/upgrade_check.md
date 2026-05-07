# upgrade_check.sh

Compares local and remote NZBGetVPN metadata and shows upgrade/changelog impact.

## Usage

Manual:

```sh
/data/scripts/upgrade_check.sh
```

Optional variables:

```text
UPGRADE_CHECK_REPO=marc0janssen/nzbgetvpn
UPGRADE_CHECK_BRANCH=develop
UPGRADE_CHECK_CHANNEL=stable
UPGRADE_CHECK_TIMEOUT=15
UPGRADE_CHECK_CHANGELOG_LIMIT=4
```

Scheduled:

```text
VPN_CRON_SCHEDULE=0 8 * * *
VPN_CRON_SCRIPT=/data/scripts/upgrade_check.sh
VPN_CRON_SCRIPT_TIMEOUT=60
```

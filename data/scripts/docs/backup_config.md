# backup_config.sh

Creates timestamped `tar.gz` backups (default source `/config`, default target `/data/backups`).

## Common Variables

```text
BACKUP_SOURCE_DIR=/config
BACKUP_TARGET_DIR=/data/backups
BACKUP_FILENAME_PREFIX=nzbgetvpn-config-backup
BACKUP_KEEP_COUNT=10
NZBGETVPN_TIMESTAMP_TZ=utc
```

## Usage

Manual:

```sh
/data/scripts/backup_config.sh
```

Dedicated backup schedule:

```text
BACKUP_CRON_SCHEDULE=0 */6 * * *
BACKUP_CRON_SCRIPT=/data/scripts/backup_config.sh
BACKUP_CRON_SCRIPT_TIMEOUT=300
```

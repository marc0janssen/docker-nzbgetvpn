# NZBGetVPN Backups

This directory is the default destination for the bundled config-backup helper script:

```text
/data/scripts/backup_config.sh
```

Default behavior:

- Source: `/config`
- Destination: `/data/backups`
- Archive format: `.tgz`
- Retention: keeps the newest 10 archives (`BACKUP_KEEP_COUNT`)

Archives may contain sensitive data (VPN profiles, keys, NZBGet credentials, provider tokens). Keep this directory private and include it in your host-level backup strategy as needed.

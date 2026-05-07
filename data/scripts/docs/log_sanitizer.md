# log_sanitizer.sh

Sanitizes logs before sharing by redacting common secrets, IP addresses, and absolute paths.

## Usage

File to file:

```sh
/data/scripts/log_sanitizer.sh /data/nzbgetvpn.log /data/nzbgetvpn.sanitized.log
```

From Docker logs:

```sh
docker logs nzbgetvpn 2>&1 | /data/scripts/log_sanitizer.sh > /data/nzbgetvpn-dockerlogs.sanitized.log
```

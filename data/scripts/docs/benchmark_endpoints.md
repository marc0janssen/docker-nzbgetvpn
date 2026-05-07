# benchmark_endpoints.sh

Benchmarks multiple endpoints (speed + latency) and reports the best candidate.

## Common Variables

```text
BENCHMARK_ENDPOINTS=https://speed.cloudflare.com/__down?bytes=4000000,https://proof.ovh.net/files/10Mb.dat
BENCHMARK_ATTEMPTS=2
BENCHMARK_TIMEOUT=20
BENCHMARK_BEST_FILE=/data/benchmark-best-endpoint.txt
BENCHMARK_OUTPUT_FILE=/data/benchmark-endpoints.json
```

## Usage

Manual:

```sh
/data/scripts/benchmark_endpoints.sh
```

Scheduled:

```text
VPN_CRON_SCHEDULE=*/30 * * * *
VPN_CRON_SCRIPT=/data/scripts/benchmark_endpoints.sh
VPN_CRON_SCRIPT_TIMEOUT=90
```

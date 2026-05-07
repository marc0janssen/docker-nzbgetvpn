# Runtime Smoke Test

This directory contains a fast end-to-end smoke test flow for runtime behavior.

## Purpose

The smoke test catches runtime breaks that syntax checks cannot detect.

It validates:

- container starts successfully
- NZBGet web UI port `6789/tcp` is reachable
- Privoxy port `8118/tcp` is reachable when `ENABLE_PRIVOXY=yes`
- base self-test exits successfully (`/root/healthcheck.sh` and `/home/nobody/vpn-selftest.sh`)

## Files

- `docker-compose.smoke.yml`: isolated smoke-test stack for CI and local runs.
- `../scripts/ci-smoke-test.sh`: orchestrates startup, checks, and cleanup.
- `../.github/workflows/smoke-test.yml`: runs the smoke test on `push` and `pull_request`.

## Local Usage

From repository root:

```sh
./scripts/ci-smoke-test.sh
```

The smoke stack defaults to `SMOKE_PLATFORM=linux/amd64` because the pinned base image is published for amd64.

If needed, you can override the platform:

```sh
SMOKE_PLATFORM=linux/amd64 ./scripts/ci-smoke-test.sh
```

Requirements on the host:

- Docker with Compose support (`docker compose`)
- `nc` (`netcat`) for TCP reachability checks

On success, the script prints `Smoke test passed`.

By default, the script cleans up the stack after exit.

To keep the stack running for debugging:

```sh
KEEP_SMOKE_STACK=yes ./scripts/ci-smoke-test.sh
```

## Debugging

Useful commands:

```sh
docker compose -f ci/docker-compose.smoke.yml ps
docker compose -f ci/docker-compose.smoke.yml logs --no-color
docker compose -f ci/docker-compose.smoke.yml down -v --remove-orphans
```

If you see `no match for platform in manifest`, run with `SMOKE_PLATFORM=linux/amd64`.

# Changelog

All notable changes to this project are documented in this file.

This project uses semantic versioning for the NZBGetVPN image/codebase version stored in `VERSION`.

## [4.5.1] - 2026-05-07

### Fixed

- Made self-test state tracking best-effort and atomic so permission issues on the state file cannot fail the self-test (prevents Docker healthcheck from flipping unhealthy due to state persistence errors).

## [4.5.0] - 2026-05-07

### Added

- `VPN_SELFTEST_STATUS_FILE`: optional JSON status snapshot written atomically after each self-test run for automation/monitoring.

## [4.4.0] - 2026-05-07

### Added

- `VPN_SELFTEST_STATE_HOOK`: optional executable script triggered when self-test readiness state changes between `ready` and `not_ready`.
- `VPN_SELFTEST_STATE_FILE` (default `/tmp/nzbgetvpn-selftest-state`) and `VPN_SELFTEST_STATE_HOOK_TIMEOUT` (default `30`) to persist state and bound hook execution.

## [4.3.0] - 2026-05-07

### Added

- `VPN_SELFTEST_NZBGET_PORT` to configure which TCP port the internal self-test checks for NZBGet listen readiness (default `6789`, validated to `1-65535` with safe fallback).

## [4.2.0] - 2026-05-07

### Added

- Native Docker `HEALTHCHECK` integration in both Dockerfiles, backed by a new `/root/healthcheck.sh` wrapper that runs the internal VPN self-test.
- `VPN_HEALTHCHECK_ENABLED` runtime toggle (`yes`/`no`/boolean, default `yes`) for opting out of container health probes without disabling self-test scheduling.

## [4.1.11] - 2026-05-07

### Changed

- Clear `VPN_SELFTEST_READY_FILE` once at watchdog startup when self-test mode is enabled, so container restarts begin in a not-ready state until a fresh self-test succeeds.
- Documented startup stale-ready-file cleanup behavior in both README files.

## [4.1.10] - 2026-05-07

### Fixed

- Corrected the NZBGet listen-port detection regex in `run/nobody/vpn-selftest.sh` to match `:6789` socket addresses (IPv4/IPv6), preventing false warnings when NZBGet is already reachable.

## [4.1.9] - 2026-05-07

### Changed

- Clarified self-test readiness semantics in both README files: `VPN_SELFTEST_ENABLED=yes` is a one-shot startup snapshot, while cron schedules provide continuous readiness updates (including ready-file refresh/removal over time).

## [4.1.8] - 2026-05-06

### Added

- `VPN_SELFTEST_READY_FILE`: optional absolute path; on successful self-test, `vpn-selftest.sh` writes a one-line `ok <UTC ISO8601>` stamp (atomic replace). The file is removed when the self-test exits with critical failures.
- `VPN_SELFTEST_READY_STRICT`: when `yes`/`true`/`1`, the ready file is written only if there are zero warnings; otherwise any existing file is removed.

## [4.1.7] - 2026-05-06

### Changed

- Moved VPN self-test execution to the end of each watchdog loop pass so `preruncheck` has populated `vpn_ip` and NZBGet may already be starting.
- Pass `vpn_ip`, `VPN_DEVICE_TYPE`, and `VPN_ENABLED` into `vpn-selftest.sh` from the watchdog.
- Derive tunnel IPv4 from `VPN_DEVICE_TYPE` in `vpn-selftest.sh` when `vpn_ip` is unset.
- Wait up to about 12 seconds (24 x 0.5s) for NZBGet to listen on port `6789` before warning.

## [4.1.6] - 2026-05-06

### Changed

- Combined `[supervisord] loglevel=info` with direct `stdout_logfile=/dev/fd/1` / `stderr_logfile=/dev/fd/2` in `build/nzbget.conf` so Docker logs stay readable (no swallowed banner) while suppressing `DEBG 'watchdog-script' stdout output:` noise from supervisord.

## [4.1.5] - 2026-05-06

### Changed

- Pointed supervisor program `stdout_logfile`/`stderr_logfile` at `/dev/fd/1` and `/dev/fd/2` in `build/nzbget.conf` so script output goes directly to Docker logs without noisy `DEBG 'watchdog-script' stdout output:` lines from supervisord child capture.

## [4.1.4] - 2026-05-06

### Fixed

- Reverted the supervisor loglevel override in `build/nzbget.conf` because it suppressed child script stdout lines, including the startup NZBGetVPN version banner and self-test logs.

## [4.1.3] - 2026-05-06

### Changed

- Set supervisor log level to `info` in `build/nzbget.conf` to suppress noisy debug-prefixed lines like `DEBG 'watchdog-script' stdout output:` in normal container logs.

## [4.1.2] - 2026-05-06

### Changed

- Reduced noisy/empty-looking supervisor log events from firewall startup output by removing decorative separator echoes and filtering blank lines from `ip route` and `iptables -S` output in `run/root/iptable.sh`.

## [4.1.1] - 2026-05-06

### Changed

- Added an upper bound for `VPN_SELFTEST_STARTUP_DELAY` in watchdog processing: values above `300` seconds are now clamped to `300` with a warning.

## [4.1.0] - 2026-05-06

### Added

- Added `VPN_SELFTEST_STARTUP_DELAY` (default `20` seconds) to delay one-shot self-test execution in `VPN_SELFTEST_ENABLED=yes` mode and reduce startup timing warnings.

### Changed

- Added watchdog log output that reports when the one-shot self-test is intentionally delayed during startup.

## [4.0.2] - 2026-05-06

### Changed

- Added watchdog startup logging for the resolved self-test mode (`VPN self-test watchdog mode ...`) so it is visible whether the watchdog receives `VPN_SELFTEST_ENABLED` as expected.

## [4.0.1] - 2026-05-06

### Changed

- Added explicit startup-complete logging of `VPN_SELFTEST_ENABLED` after NZBGet starts listening on port `6789`, including both normalized mode and raw environment value.

## [4.0.0] - 2026-05-06

### Changed

- Renamed the one-shot startup self-test mode from `afterstart` to `yes` for `VPN_SELFTEST_ENABLED`.
- Updated self-test parsing so `true`/`1` normalize to `yes` and `false`/`0` normalize to `no`.
- Updated `README.md` and `README-containers.md` examples and accepted values to document `no`, `yes`, or cron expression.

## [3.2.0] - 2026-05-06

### Changed

- Extended boolean parsing across project scripts to also accept `1` and `0` alongside `yes`/`no` and `true`/`false`.
- Updated runtime script toggles and helper-script filename toggles to normalize all six boolean forms consistently.
- Updated build and update helper scripts so checksum-acceptance logic also accepts `true` and `1`.
- Updated README documentation to list `1` and `0` as supported boolean alternatives and clarified self-test boolean aliases.

## [3.1.0] - 2026-05-06

### Changed

- Updated repository runtime scripts to accept both `yes`/`no` and `true`/`false` for boolean environment variables they consume.
- Added boolean normalization for internal toggles (`VPN_ENABLED`, `ENABLE_PRIVOXY`, `DEBUG`, `VPN_UNHEALTHY_TEST`) and for helper script filename toggles (`*_CONFIG_USE_SOURCE_FILENAME`).
- Kept `VPN_SELFTEST_ENABLED` scheduling values while also accepting `true` as `afterstart` and `false` as `no`.
- Updated documentation examples and boolean normalization guidance in `README.md` and `README-containers.md`.

## [3.0.0] - 2026-05-06

### Changed

- Simplified `VPN_SELFTEST_ENABLED` accepted values to only `no` (default), `afterstart`, or a five-field cron expression such as `*/5 * * * *`.
- Removed temporary `yes` and `no` compatibility aliases for self-test scheduling.
- Improved invalid-schedule logging so self-test cron parsing errors reference `VPN_SELFTEST_ENABLED`.
- Updated self-test documentation in `README.md` and `README-containers.md` to reflect the final accepted values.

## [2.2.3] - 2026-05-06

### Changed

- Extended `VPN_SELFTEST_ENABLED` scheduling behavior to accept `none` (default), `afterstart`, and five-field cron expressions like `*/5 * * * *`.
- Kept backward compatibility by mapping `VPN_SELFTEST_ENABLED=yes` to `afterstart` and `VPN_SELFTEST_ENABLED=no` to `none`.
- Updated self-test documentation in `README.md` and `README-containers.md` with startup and periodic scheduling examples.

## [2.2.2] - 2026-05-06

### Added

- Added internal startup self-test script `run/nobody/vpn-selftest.sh` that performs read-only checks for container routing, DNS resolver presence, writable data/config paths, VPN interface signaling, and NZBGet process/listener state.
- Added `VPN_SELFTEST_ENABLED` to run the internal self-test once from the watchdog loop and log results to normal Docker container output.

### Changed

- Documented the new internal self-test toggle and behavior in `README.md` and `README-containers.md`, including that the script remains internal at `/home/nobody/vpn-selftest.sh` and is not exposed via `/data/scripts`.

## [2.2.1] - 2026-05-04

### Added

- Added OCI image labels to stable and testing Dockerfiles for registry metadata.
- Passed the NZBGetVPN image/codebase version into Docker builds as `NZBGETVPN_VERSION`.
- Reused `BASE_IMAGE_TAG` for both the Dockerfile base image and OCI base-image label.

## [2.2.0] - 2026-05-04

### Added

- Added Docker Compose examples for stable and testing image onboarding.
- Added `SECURITY.md` with vulnerability reporting scope and secret-handling guidance.
- Documented default NZBGet credential hardening and simple `/config` plus `/data` backup/restore guidance.

## [2.1.5] - 2026-05-04

### Fixed

- Documented the previous stable base image tag in the stable Dockerfile for parity with the testing Dockerfile.

## [2.1.4] - 2026-05-04

### Fixed

- Restored the standalone NZBGet version Docker tag in stable and testing builds.
- Removed unused `NZBGET_CACERT_SHA256` metadata from the testing Dockerfile.

### Changed

- Simplified the startup-complete version log to write to normal stdout now that supervisor duplicate logging is fixed.

## [2.1.3] - 2026-05-04

### Added

- Added the maintainer contact page URL to the startup-complete version log line.

## [2.1.2] - 2026-05-04

### Fixed

- Stopped supervisor program logs from also writing directly to Docker stdout/stderr, preventing duplicate raw and supervisord-prefixed log lines.

## [2.1.1] - 2026-05-04

### Fixed

- Changed the startup-complete version log to a single line to avoid duplicated supervisord debug output.
- Added the NZBGet application version to the startup-complete version log.

## [2.1.0] - 2026-05-04

### Added

- Added the NZBGetVPN image/codebase `VERSION` file to stable and testing images.
- Added a startup-complete log banner after NZBGet is listening that shows the NZBGetVPN image/codebase version and links to the GitHub changelog.

### Fixed

- Pointed the startup changelog log line at the repository `develop` branch so it resolves after these changes are pushed.

## [2.0.1] - 2026-05-04

### Changed

- Changed `scripts/update-base-image.sh` so resolving `newest` bumps the NZBGetVPN image/codebase patch version when it pins a different base image tag.
- Updated build documentation to mention that `--base newest` bumps `VERSION` only when the resolved base tag changes.

## [2.0.0] - 2026-05-04

### Changed

- Pinned the stable Dockerfile base image to a numeric `binhex/arch-int-vpn` tag instead of `latest`.
- Changed NZBGet update flows to require either `--sha256 <expected-sha256>` or `--accept-downloaded-sha256` before writing a downloaded artifact checksum into a Dockerfile.
- Tightened Docker tag and image codebase version validation in stable and testing build scripts.
- Quoted Docker build tag arguments in stable and testing build scripts.
- Updated README documentation for the explicit checksum verification gate.

### Security

- Reduced stable image supply-chain drift by removing the mutable `latest` base tag.
- Made checksum pinning an explicit operator decision instead of silently trusting the downloaded NZBGet artifact.

## [1.0.1] - 2026-05-04

### Changed

- Clarified `AGENTS.md` role expectations for future coding agents: act as a senior architect, shell expert, security specialist, Docker/container expert, networking expert, and NZB/downloading/VPN domain expert.
- Documented that security-sensitive VPN, provider API, downloader and firewall changes should favor robust, auditable solutions.

## [1.0.0] - 2026-05-04

### Added

- Added `VERSION` as the NZBGetVPN image/codebase version source.
- Added combined Docker image version tags:
  - stable: `<nzbget-version>-image-v<version>`, for example `26.1-image-v1.0.0`
  - testing: `<nzbget-testing-version>-image-v<version>`, for example `26.2-testing-20260501-image-v1.0.0`
- Added `README-containers.md` as a compact Docker Hub description to stay under Docker Hub's size limit.
- Added bundled helper scripts that are copied into `/data/scripts` at container startup:
  - `get_wireguard_configs_nordvpn.sh`
  - `select_random_wireguard_config.sh`
  - `select_random_openvpn_config.sh`
- Added `/data/scripts/README.md`.
- Added `/data/wireguard-configs/README.md`.
- Added `/data/openvpn-configs/README.md`.
- Added startup creation for:
  - `/data/scripts`
  - `/data/wireguard-configs`
  - `/data/openvpn-configs`
- Added startup installation/update of bundled helper scripts from image templates, so mounted `/data/scripts` copies are refreshed when the image version changes.
- Added NordVPN WireGuard config generation support through `get_wireguard_configs_nordvpn.sh`.
- Added random WireGuard config selection from `/data/wireguard-configs`.
- Added random OpenVPN profile selection from `/data/openvpn-configs`.
- Added optional source filename preservation:
  - `WIREGUARD_CONFIG_USE_SOURCE_FILENAME=yes`
  - `OPENVPN_CONFIG_USE_SOURCE_FILENAME=yes`
- Added configurable target filenames:
  - `WIREGUARD_CONFIG_FILENAME`, default `wg0.conf`
  - `OPENVPN_CONFIG_FILENAME`, default `openvpn.ovpn`
- Added documentation for creating `NORDVPN_ACCESS_TOKEN` through Nord Account.
- Added `jq` to build-time package installation because the NordVPN helper script requires it.

### Changed

- Changed Docker Hub README publishing to explicitly use `README-containers.md`.
- Changed `get_wireguard_configs_nordvpn.sh` to default to one active WireGuard config at `/config/wireguard/wg0.conf`.
- Changed `get_wireguard_configs_nordvpn.sh` so `TOTAL_CONFIGS > 1` fetches multiple NordVPN recommendations and randomly selects one generated config.
- Changed bundled script deployment so existing mounted helper scripts are updated when they differ from the image template.
- Updated `.gitignore` to allow only tracked helper scripts and README templates under `data/`, while still ignoring real local VPN config files and secrets.
- Updated README documentation for base-image behavior, helper scripts, cron/unhealthy script usage, build flow, Docker tags, and troubleshooting.

### Fixed

- Fixed NordVPN recommendations API calls by using `curl --globoff` for query parameters containing square brackets.
- Fixed inconsistent `WIREGUARD_CONFIG_FILENAME` behavior between the NordVPN WireGuard script and the random WireGuard selector.
- Fixed missing default source directories for random OpenVPN/WireGuard config selection when `/data` is a bind mount.

### Security

- Removed the need to hardcode a NordVPN token in helper scripts by documenting and using `NORDVPN_ACCESS_TOKEN`.
- Kept generated and selected VPN config files at `chmod 600`.
- Preserved existing target VPN configs until a replacement config has been successfully prepared.

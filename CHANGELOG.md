# Changelog

All notable changes to this project are documented in this file.

This project uses semantic versioning for the NZBGetVPN image/codebase version stored in `VERSION`.

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

# Changelog

All notable changes to this project are documented in this file.

This project uses semantic versioning for the NZBGetVPN image/codebase version stored in `VERSION`.

## [5.5.8] - 2026-05-09

### Changed

- Fixed ARM64 package database sync in `build/root/install.sh` by writing an Arch Linux ARM mirrorlist when `OS_ARCH=aarch64`.
- Disabled the optional `[aur]` repository during ARM sync to prevent `aur.db` 404 failures that blocked `pacman -Syyu` in multi-arch builds.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.7] - 2026-05-09

### Changed

- Replaced the default `ROTATE_SPEEDTEST_URLS` in `data/scripts/lib.sh` to remove the unstable `freetestdata.com` endpoint and use `proof.ovh.net` as primary with a Mozilla CDN fallback.
- Regenerated `data/scripts/docs/rotate_on_poor_speed.md` defaults documentation via `scripts/sync-rotate-defaults-doc.sh`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.6] - 2026-05-09

### Changed

- Updated `.github/workflows/drift-radar.yml` to also run on `pull_request` for `develop`, so the `dependency-drift-radar` check can report a commit-linked `passed` status in PRs.
- Scoped issue management and auto-refresh PR steps to non-PR events, keeping scheduled/manual drift automation behavior unchanged.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.5] - 2026-05-09

### Changed

- Updated GitHub Actions in CI workflows to Node.js 24-ready versions by moving `actions/checkout` from `v4` to `v5` and `actions/github-script` from `v7` to `v8` in the dependency drift radar workflow.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.4] - 2026-05-09

### Changed

- Stabilized release quality checks by extending the temporary shellcheck baseline excludes in `scripts/ci-quality-checks.sh` with legacy style findings (`SC2002`, `SC2236`) that are outside this change scope.
- Fixed shellcheck findings introduced by recent CI additions: quoted parameter expansion in `data/scripts/container/doctor.sh` (`SC2295`) and grouped GitHub output writes in `scripts/ci-drift-radar.sh` (`SC2129`).
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.3] - 2026-05-09

### Changed

- Expanded `README-containers.md` CI status badges to include `security-scan.yml`, `drift-radar.yml`, and `release-orchestration.yml` alongside quality and smoke workflows.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.2] - 2026-05-09

### Changed

- Expanded `README.md` CI status badges to include `security-scan.yml`, `drift-radar.yml`, and `release-orchestration.yml` alongside quality and smoke workflows.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.1] - 2026-05-09

### Changed

- Fixed workflow action references by pinning Trivy to an existing tag format (`aquasecurity/trivy-action@v0.36.0`) in `.github/workflows/security-scan.yml` and `.github/workflows/release-orchestration.yml`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.5.0] - 2026-05-09

### Added

- Added release ownership policy via `.github/CODEOWNERS` for runtime, scripts, and workflow paths.
- Added release-readiness workflow `.github/workflows/release-orchestration.yml` to run quality, smoke, and security checks for manual runs and version tags.

### Changed

- Extended drift automation to expose detailed outputs in `scripts/ci-drift-radar.sh` and enhanced `.github/workflows/drift-radar.yml` to auto-close resolved drift issues and open/update a base-refresh PR when applicable.
- Added failure diagnostics artifact uploads to `.github/workflows/quality-checks.yml` and `.github/workflows/smoke-test.yml`.
- Added Trivy baseline support via `.trivyignore` and diagnostic artifact uploads in `.github/workflows/security-scan.yml`.
- Updated CI docs in `ci/README.md` for release orchestration, drift automation, and security baseline behavior.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.4.2] - 2026-05-09

### Added

- Added GitHub Actions security workflow `.github/workflows/security-scan.yml` with Trivy filesystem scanning, SARIF upload to GitHub Security, and configurable severity enforcement (`TRIVY_FAIL_SEVERITY`, default `CRITICAL`).

### Changed

- Updated CI documentation in `ci/README.md` with security scan workflow details.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.4.1] - 2026-05-09

### Changed

- Extended `.github/workflows/drift-radar.yml` to automatically create or update a single open `drift-radar` issue when drift is detected, using the generated markdown summary from `scripts/ci-drift-radar.sh`.
- Updated `scripts/ci-drift-radar.sh` to export the markdown report as a workflow output for downstream issue automation.
- Updated CI docs in `ci/README.md` to document drift issue automation behavior.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.4.0] - 2026-05-09

### Added

- Added dependency drift radar script `scripts/ci-drift-radar.sh` to compare pinned stable/testing NZBGet and base-image tags against latest upstream values and publish a markdown summary.
- Added scheduled GitHub Actions workflow `.github/workflows/drift-radar.yml` (weekly + manual dispatch) to run the drift radar in CI.

### Changed

- Updated CI docs in `ci/README.md` with the new drift radar script/workflow references.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.9] - 2026-05-09

### Changed

- Extended runtime smoke coverage in `scripts/ci-smoke-test.sh` with a `doctor.sh --heal` recovery scenario that injects drift into `/data/scripts/lib.sh`, verifies restore to bundled state, and confirms backups under `/data/backups/doctor-heal-*`.
- Updated smoke test documentation in `ci/README.md` to include the `doctor.sh --heal` recovery validation.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.8] - 2026-05-09

### Changed

- Added CI idempotence checks in `scripts/ci-quality-checks.sh` that run `sync-rotate-defaults-doc.sh` and `update-base-image.sh` twice and fail when those update scripts still produce repository diffs.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.7] - 2026-05-09

### Changed

- Added a CI versioning metadata guard to `scripts/ci-quality-checks.sh` that fails when non-metadata changes are made without updating `VERSION`, `CHANGELOG.md`, `README.md`, and `README-containers.md`, and also verifies README version lines match `VERSION`.
- Updated `.github/workflows/quality-checks.yml` checkout to `fetch-depth: 0` so commit-range based checks have full history context.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.6] - 2026-05-09

### Changed

- Updated `scripts/update-base-image.sh` to also refresh the `Base image stable/testing tag` lines in `README.md` and `README-containers.md` when a Dockerfile base image tag is changed.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.5] - 2026-05-09

### Changed

- Added base-image version lines to the `Versions` section in `README.md` and `README-containers.md`, showing stable and testing `binhex/arch-int-vpn` tags.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.4] - 2026-05-09

### Changed

- Updated Dockerfile base image tag from `binhex/arch-int-vpn:2026032801` to `binhex/arch-int-vpn:2026050402` via `--base newest`.
- Automatically bumped version metadata in `VERSION`, `README.md`, and `README-containers.md`.


## [5.3.3] - 2026-05-09

### Changed

- Expanded `data/scripts/docs/doctor.md` with a troubleshooting section that explains common `doctor.sh` warnings for disabled internet reachability checks and missing `VPN_DEVICE_TYPE`, including concrete commands to enable those checks.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.2] - 2026-05-09

### Changed

- Updated `scripts/update-base-image.sh` to automatically insert a changelog entry when `--base newest` resolves to a new base-image tag and triggers a patch version bump.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.1] - 2026-05-09

### Changed

- Added runtime `BASE_IMAGE_TAG` environment export in `Dockerfile` and `Dockerfile-testing` so scripts can reliably report the inherited base-image tag.
- Updated startup version log line in `run/nobody/nzbget.sh` to include `Base image binhex/arch-int-vpn:<tag>`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.3.0] - 2026-05-09

### Added

- Added `--heal` mode to `data/scripts/container/doctor.sh` to force-resync managed bundled templates from image copies before running diagnostics.
- `doctor.sh --heal` now creates safety backups for replaced files under `/data/backups/doctor-heal-<timestamp>/`.

### Changed

- Updated helper documentation in `README.md`, `README-containers.md`, `data/scripts/README.md`, and `data/scripts/docs/doctor.md` with `doctor.sh --heal` usage guidance.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.2.2] - 2026-05-09

### Changed

- Removed README/docs preserve-marker diagnostics from `doctor.sh`; preserve-marker checks now target runtime-managed files only.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.2.1] - 2026-05-09

### Changed

- Refined bundled-file preserve behavior so preserve markers are only honored for managed runtime script files (`*.sh` and `/data/scripts/lib.sh`) in `BUNDLED_SYNC_POLICY=smart`.
- Bundled docs/README templates now keep syncing in `smart` mode even when they contain a preserve marker, preventing documentation drift from stale local markers.
- Updated `doctor.sh` preserve-marker diagnostics to warn for runtime files and treat README-marker hits as informational-only.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.2.0] - 2026-05-09

### Added

- Added startup bundled-file sync policy `BUNDLED_SYNC_POLICY` in `build/root/install.sh` with modes: `smart` (default), `force`, and `preserve`.
- Added preserve-marker support (`nzbgetvpn: preserve-local`) for managed `/data` bundled files when `BUNDLED_SYNC_POLICY=smart`.

### Changed

- Startup now logs explicit warnings whenever bundled file updates are skipped due to preserve policy or preserve marker, including a note that preserving local files can break behavior after image upgrades.
- Added `doctor.sh` checks for `BUNDLED_SYNC_POLICY` and preserve markers, including warnings that preserved managed files can drift and break behavior after upgrades.
- Updated script documentation and environment-variable docs for bundled sync behavior in `README.md`, `README-containers.md`, and `data/scripts/README.md`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.1.0] - 2026-05-09

### Changed

- Updated startup sync in `build/root/install.sh` to also sync `/data/scripts/lib.sh` from the bundled image copy whenever it differs.
- Updated startup sync logic for bundled README files under `/data/{scripts,wireguard-configs,openvpn-configs,backups}/` so existing files are refreshed when they differ from image templates.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.0.4] - 2026-05-09

### Changed

- Bumped NZBGetVPN image/codebase patch version to `5.0.4`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.0.3] - 2026-05-09

### Changed

- Default `ROTATE_SPEEDTEST_URLS` primary endpoint is now `https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_1OMB_MP3.mp3` instead of Cloudflare `speed.cloudflare.com/__down`; OVH `proof.ovh.net` remains the weighted secondary (backup) mirror.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.0.2] - 2026-05-09

### Changed

- Default `ROTATE_SPEEDTEST_URLS` uses Cloudflare `speed.cloudflare.com/__down` as the primary endpoint and keeps OVH `proof.ovh.net` only as the weighted secondary (backup) mirror; Hetzner `speed.hetzner.de` is no longer in the default list.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.0.1] - 2026-05-09

### Changed

- Default `ROTATE_SPEEDTEST_URLS` now uses European HTTP download mirrors (Hetzner `speed.hetzner.de`, OVH `proof.ovh.net`) instead of Cloudflare `speed.cloudflare.com/__down`, which has no region-specific URL and often exits far from Europe.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [5.0.0] - 2026-05-08

### Breaking

- Removed legacy flat bundled helper paths in `/data/scripts/*.sh`; bundled scripts are now only managed in categorized folders under `/data/scripts/{container,shared,notify,host}/`. Existing setups that reference flat script paths must update to category paths.

### Fixed

- Corrected POSIX shell compatibility in `data/scripts/host/run-container-helper.sh` by replacing Bash-specific `[[ ... ]]` with portable `[ ... ]`, fixing runtime errors on systems where `/bin/sh` is `dash`.

### Changed

- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.36] - 2026-05-08

### Changed

- Removed bundled flat script compatibility in `/data/scripts/*.sh`; startup sync now keeps only categorized helper paths under `/data/scripts/{container,shared,notify,host}/` and removes legacy flat bundled copies.
- Updated helper defaults and runtime references to categorized paths (`data/scripts/lib.sh`, `run/nobody/watchdog.sh`) and updated host helper lookup in `data/scripts/host/run-container-helper.sh` to resolve scripts across category folders.
- Updated helper-path documentation in `README.md`, `README-containers.md`, `data/scripts/README.md`, `data/openvpn-configs/README.md`, and `data/wireguard-configs/README.md`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.35] - 2026-05-08

### Changed

- Removed repository wrapper `scripts/run-container-helper.sh` and standardized host-helper usage/documentation on the source path `data/scripts/host/run-container-helper.sh`, which is bundled into the image and synced to `/data/scripts/host/`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.34] - 2026-05-08

### Added

- Added bundled host helper source `data/scripts/host/run-container-helper.sh` so host-side wrapper logic is included in the image templates and synced to `/data/scripts/host/`.

### Changed

- Updated startup sync in `build/root/install.sh` to include `/data/scripts/host/` from bundled image templates.
- Updated both Dockerfiles and `.gitignore` for the new `data/scripts/host/*.sh` source path.
- Updated script documentation (`data/scripts/README.md`, `AGENTS.md`) to include the `host` category and host-only run context.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.33] - 2026-05-08

### Changed

- Updated startup script sync in `build/root/install.sh` to populate `/data/scripts/{container,shared,notify}/` from bundled image templates while still maintaining flat `/data/scripts/<name>.sh` compatibility copies for existing scheduler/hook paths.
- Updated both Dockerfiles to include category-specific bundled script paths under `/usr/local/share/nzbgetvpn/scripts/{container,shared,notify}/` so category sync sources are present in the image.
- Clarified bundled script install behavior in `data/scripts/README.md` and `AGENTS.md`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.32] - 2026-05-08

### Added

- Added host-side helper `scripts/run-container-helper.sh` to run bundled `/data/scripts/*.sh` safely inside a running container via `docker exec`, with container state checks and script-name validation.

### Changed

- Updated helper-script usage docs in `data/scripts/README.md`, `README.md`, and `README-containers.md` to include host-side wrapper usage.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.31] - 2026-05-08

### Changed

- Renamed helper source folder `data/scripts/portable/` to `data/scripts/shared/` for clearer intent, and updated Docker build inputs plus repository documentation (`Dockerfile`, `Dockerfile-testing`, `data/scripts/README.md`, `AGENTS.md`) accordingly.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.30] - 2026-05-08

### Changed

- Reorganized bundled helper script sources into category folders under `data/scripts/` (`container/`, `portable/`, `notify/`) while preserving runtime compatibility by continuing to install helpers into flat `/usr/local/share/nzbgetvpn/scripts/*.sh` and `/data/scripts/*.sh` paths.
- Updated Docker build inputs (`Dockerfile`, `Dockerfile-testing`) and shell-quality validation (`scripts/ci-quality-checks.sh`, `AGENTS.md`) to include the new helper-script source layout.
- Expanded `data/scripts/README.md` with a source-layout section that explains repository organization versus flattened runtime install paths.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.29] - 2026-05-08

### Changed

- Updated `data/scripts/README.md` with explicit run-context classification per helper script (`Container-only`, `Host-or-container`, `Container-first`, and `Internal library`) so operators can quickly see where each script should be executed.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.28] - 2026-05-08

### Changed

- Expanded `data/scripts/doctor.sh` diagnostics with default-route and DNS-entry validation, VPN interface/IP signal checks, and an optional internet reachability probe (`DOCTOR_INTERNET_CHECK_*`).
- Updated `data/scripts/docs/doctor.md` with the extended checks and new optional variables.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.27] - 2026-05-08

### Added

- Added bundled diagnostics helper `data/scripts/doctor.sh` to run quick runtime/config readiness checks for commands, writable volumes, DNS resolver presence, and VPN profile availability based on `VPN_CLIENT`.

### Changed

- Updated helper-script docs and README references to document `doctor.sh`.
- Updated version metadata in `VERSION`, `README.md`, and `README-containers.md`.

## [4.24.26] - 2026-05-08

### Changed

- Polished `README.md` quick-start guidance by adding explicit first-login credential hardening instructions (`nzbget` / `tegbzn6789` must be changed after initial startup).
- Clarified in `README.md` that boolean-style toggles accept `yes`/`no`, `true`/`false`, and `1`/`0`.
- Updated version metadata in `VERSION` and `README-containers.md`.

## [4.24.25] - 2026-05-07

### Changed

- Added `data/scripts/docs/*.md` to both Dockerfiles so helper-script documentation is bundled into the image under `/usr/local/share/nzbgetvpn/scripts/docs/`.
- Extended startup install/sync logic in `build/root/install.sh` to install and update bundled script docs into `/data/scripts/docs/` alongside bundled helper scripts.
- Updated `README.md` and `README-containers.md` to document container-side availability of bundled script docs.

## [4.24.24] - 2026-05-07

### Changed

- Extended `scripts/ci-quality-checks.sh` with hard CI guards for unresolved merge-conflict markers and Docker Hub README size limits (`README-containers.md` must remain below `25000` bytes).
- Added optional conventional commit lint support in quality checks via `CI_CONVENTIONAL_COMMIT_LINT` and `CI_CONVENTIONAL_COMMIT_RANGE`, and wired workflow defaults in `.github/workflows/quality-checks.yml`.
- Updated `README.md` and `README-containers.md` CI documentation with the new guards and optional commit-lint activation flow.

## [4.24.23] - 2026-05-07

### Fixed

- Hardened fail-safe idempotency in `run/root/iptable.sh` by introducing a reusable `ip rule` check-before-add helper for fwmark routes, preventing duplicate rule insertion across restarts and retries.

## [4.24.22] - 2026-05-07

### Fixed

- Hardened `scripts/latest-nzbget-version.sh` testing-channel lookup against GitHub API `403` rate-limit/abuse responses by adding token-aware API auth (`GITHUB_TOKEN`/`GH_TOKEN`) and an HTML fallback that reads `releases/expanded_assets/testing` to resolve the current `nzbget-*-bin-linux.run` asset.

## [4.24.21] - 2026-05-07

### Fixed

- Updated testing release pinning to `26.2-testing-20260507` in `Dockerfile-testing`, `README.md`, and `README-containers.md` so testing builds no longer point at a removed release asset.
- Hardened `build.sh` and `build-testing.sh` argument handling by trimming accidental leading/trailing whitespace on version/base/SHA arguments to prevent malformed download URLs during retries or copy/paste usage.

## [4.24.20] - 2026-05-07

### Fixed

- Tightened fail-safe idempotency in `run/root/iptable.sh` by switching LAN route programming to `ip route replace` and by enforcing consistent check-before-add behavior for iptables rules (including mangle marks) to avoid duplicate entries on restarts/retries.

## [4.24.19] - 2026-05-07

### Changed

- Centralized adaptive-rotation defaults in `data/scripts/lib.sh` and updated `data/scripts/rotate_on_poor_speed.sh` plus `run/nobody/watchdog.sh` to consume the shared defaults instead of duplicating hard-coded values.
- Added `scripts/sync-rotate-defaults-doc.sh` to render/check `data/scripts/docs/rotate_on_poor_speed.md` defaults from the shared runtime source and wired this drift check into `scripts/ci-quality-checks.sh`.
- Updated `README.md`, `README-containers.md`, and `data/scripts/README.md` to document the generated/validated defaults workflow.

## [4.24.18] - 2026-05-07

### Fixed

- Hardened runtime script trust boundaries by removing `/data/scripts/lib.sh` fallback from `run/root/iptable.sh`, `run/nobody/watchdog.sh`, and `run/nobody/vpn-selftest.sh`; these scripts now only source `/usr/local/share/nzbgetvpn/scripts/lib.sh`.

## [4.24.17] - 2026-05-07

### Changed

- Added shared helper library `data/scripts/lib.sh` and updated `run/nobody/watchdog.sh`, `run/nobody/vpn-selftest.sh`, `run/root/iptable.sh`, and `data/scripts/rotate_on_poor_speed.sh` to reuse common enable/normalize/path/log helper logic.
- Updated `data/scripts/README.md` with the bundled `lib.sh` helper entry for operator visibility.

## [4.24.16] - 2026-05-07

### Fixed

- Corrected remaining `shfmt --diff` formatting in `scripts/ci-quality-checks.sh` redirection spacing so local and CI quality checks pass cleanly.

## [4.24.15] - 2026-05-07

### Changed

- Applied repository-wide shell formatting with `shfmt -w` to align scripts with the enforced `shfmt --diff` quality gate.
- Updated `VERSION`, `README.md`, and `README-containers.md` version metadata after the formatting sweep.

## [4.24.14] - 2026-05-07

### Changed

- Updated `scripts/ci-quality-checks.sh` with a temporary shellcheck baseline exclude list for known legacy findings so CI can gate new regressions while cleanup is phased.
- Added strict-mode guidance (`SHELLCHECK_EXCLUDES=`) in `README.md`, `README-containers.md`, and `ci/README.md` to support full shellcheck cleanup runs.

## [4.24.13] - 2026-05-07

### Changed

- Added CI status badges and expanded CI workflow descriptions in `README.md` and `README-containers.md` for clearer visibility of automated quality and runtime checks.
- Updated `ci/README.md` to explicitly point to the separate shell-quality check workflow and local command.

## [4.24.12] - 2026-05-07

### Added

- Added GitHub Actions workflow `.github/workflows/quality-checks.yml` to run shell quality checks on `push` and `pull_request`.
- Added `scripts/ci-quality-checks.sh` to run `bash`/`sh` syntax checks on tracked scripts, `shellcheck`, `shfmt --diff`, and AGENTS.md validation commands in one CI/local entrypoint.

### Changed

- Updated `README.md` and `README-containers.md` with the new local and CI shell-quality check flow.

## [4.24.11] - 2026-05-07

### Fixed

- Removed the host-side `rg` dependency from `scripts/ci-smoke-test.sh` by replacing the running-container check with a Docker-native `docker compose ps -q` + `docker inspect` wait loop.

### Changed

- Documented host requirements (`docker compose` and `nc`) in `ci/README.md`.

## [4.24.10] - 2026-05-07

### Changed

- Updated `ci/docker-compose.smoke.yml` and `scripts/ci-smoke-test.sh` to run smoke tests with explicit platform selection (`SMOKE_PLATFORM`, default `linux/amd64`) to avoid manifest-platform mismatches on Apple Silicon and other non-amd64 hosts.
- Expanded smoke-test docs in `ci/README.md`, `README.md`, and `README-containers.md` with platform guidance and a direct workaround for `no match for platform in manifest`.

## [4.24.9] - 2026-05-07

### Added

- Added `ci/README.md` with a dedicated runtime smoke-test guide covering purpose, validated checks, local usage, optional debug mode, and troubleshooting commands.

### Changed

- Updated `README.md` and `README-containers.md` to link to the dedicated smoke-test documentation.

## [4.24.8] - 2026-05-07

### Added

- Added runtime smoke-test assets (`ci/docker-compose.smoke.yml` and `scripts/ci-smoke-test.sh`) that validate container startup, NZBGet listen port `6789`, Privoxy reachability on `8118` when enabled, and successful self-test exits.
- Added GitHub Actions workflow `.github/workflows/smoke-test.yml` to run the smoke test on push and pull request events.

### Changed

- Updated `README.md` and `README-containers.md` with a short CI smoke-test reference.

## [4.24.7] - 2026-05-07

### Changed

- Simplified `README.md` into a compact operator-focused document with generated anchor-based table of contents and direct links to detailed docs.
- Simplified `README-containers.md` to keep Docker Hub content concise while linking to full repository docs.
- Replaced the large monolithic `data/scripts/README.md` with an index-style helper overview and added per-script docs under `data/scripts/docs/` to reduce merge-conflict hotspots.

## [4.24.6] - 2026-05-07

### Changed

- Reduced the default adaptive-rotation schedule from `*/10 * * * *` to `*/20 * * * *` in `run/nobody/watchdog.sh` to lower routine probe overhead.
- Updated adaptive-rotation schedule defaults/examples in `README.md`, `README-containers.md`, and `data/scripts/README.md`.
- Added a build-time compatibility patch in `build/root/install.sh` that rewrites legacy inherited `iptable_mangle` `modprobe`/`insmod` checks to an `iptables -t mangle` capability probe, removing false startup errors on modern kernels.

## [4.24.5] - 2026-05-07

### Changed

- Updated `run/root/iptable.sh` to use numeric policy-routing table `6789` for Web UI fwmark routing so startup no longer depends on `/etc/iproute2/rt_tables` being present.
- Made fwmark routing setup idempotent by checking existing `ip rule` state and using `ip route replace` to avoid duplicate or invalid-table startup errors.

## [4.24.4] - 2026-05-07

### Changed

- Expanded helper-script documentation in `data/scripts/README.md` with a clear customization/support policy and per-script guidance on when environment-variable tuning is sufficient versus when copying a script is recommended.
- Added guidance in `README.md` to prefer env-var configuration for bundled `/data/scripts` templates and use copied script filenames for custom logic.

## [4.24.3] - 2026-05-07

### Changed

- Updated `run/root/iptable.sh` mangle-table detection to probe `iptables -t mangle` directly instead of relying on the `iptable_mangle` kernel module being listed in `lsmod`.
- Added a clearer warning when mangle support is genuinely unavailable so kernels with built-in/nft-backed support no longer report a false negative.

## [4.24.2] - 2026-05-07

### Changed

- Removed `https://raw.githubusercontent.com/marc0janssen/nzbgetvpn/develop/VERSION` from default endpoint sets in `data/scripts/rotate_on_poor_speed.sh` and `data/scripts/benchmark_endpoints.sh`.
- Updated default adaptive-rotation endpoint weights to match the new two-endpoint default set.
- Updated endpoint examples in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.24.1] - 2026-05-07

### Changed

- Removed Hetzner from the default adaptive-rotation speed endpoint list in `data/scripts/rotate_on_poor_speed.sh`.
- Updated default adaptive-rotation endpoint weights to match the new three-endpoint default set.
- Updated adaptive-rotation endpoint examples in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.24.0] - 2026-05-07

### Changed

- Updated `data/scripts/rotate_on_poor_speed.sh` to use default multi-provider speed endpoints (Cloudflare, Hetzner, OVH, GitHub raw) when no explicit endpoint override is set.
- Added optional weighted endpoint aggregation via `ROTATE_SPEEDTEST_WEIGHTS` and switched adaptive-rotation quality scoring from median to weighted speed/latency averages.
- Updated adaptive-rotation docs in `README.md`, `README-containers.md`, and `data/scripts/README.md` with default endpoint list and weight configuration examples.

## [4.23.0] - 2026-05-07

### Added

- Added multi-endpoint quality checks to `data/scripts/rotate_on_poor_speed.sh` with `ROTATE_SPEEDTEST_URLS`, `ROTATE_SPEEDTEST_ATTEMPTS`, and `ROTATE_MIN_SUCCESSFUL_ENDPOINTS`.

### Changed

- `rotate_on_poor_speed.sh` now aggregates endpoint results with median speed/latency before applying thresholds, reducing false rotations caused by one flaky endpoint.
- Updated adaptive-rotation documentation in `README.md`, `README-containers.md`, and `data/scripts/README.md` to document multi-source decision behavior and fallback compatibility with `ROTATE_SPEEDTEST_URL`.

## [4.22.0] - 2026-05-07

### Added

- Added bundled helper `data/scripts/benchmark_endpoints.sh` to run fast latency/download benchmarks across multiple endpoints, rank candidates, and report the best endpoint.

### Changed

- Documented endpoint benchmarking usage and scheduler examples in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.21.2] - 2026-05-07

### Changed

- Expanded central `README.md` with a dedicated section that consolidates key decentralized README content (`data/wireguard-configs`, `data/openvpn-configs`, and `examples`) and points to the mirrored helper-script sections.

## [4.21.1] - 2026-05-07

### Changed

- Clarified adaptive-rotation documentation: `ROTATE_POST_ROTATION_ACTION=watchdog-exit` should be paired with `restart: unless-stopped`; otherwise the container exits and remains stopped.

## [4.21.0] - 2026-05-07

### Added

- Added dedicated adaptive-rotation scheduler variables in `watchdog.sh`: `ROTATE_ON_POOR_SPEED_ENABLED` (default `yes`), `ROTATE_ON_POOR_SPEED_SCHEDULE` (default `*/10 * * * *`), `ROTATE_ON_POOR_SPEED_SCRIPT` (default `/data/scripts/rotate_on_poor_speed.sh`), and `ROTATE_ON_POOR_SPEED_TIMEOUT` (default `90`).

### Changed

- Adaptive profile rotation docs now use `ROTATE_ON_POOR_SPEED_*` instead of `VPN_CRON_*`, and include explicit enable/disable behavior.

## [4.20.0] - 2026-05-07

### Added

- Restored optional DNS leak path checks in `run/nobody/vpn-selftest.sh` with `VPN_SELFTEST_DNS_LEAK_TEST`, `VPN_SELFTEST_DNS_LEAK_STRICT`, `VPN_SELFTEST_DNS_LEAK_TIMEOUT`, and optional `VPN_SELFTEST_DNS_LEAK_HOST`.

### Changed

- Updated self-test documentation in `README.md` and `README-containers.md` to describe DNS leak check behavior and controls.

## [4.19.0] - 2026-05-07

### Added

- Added persistent container script logging to `/data/nzbgetvpn-container.log` with automatic rotation (`10MB`, `5` backups) while keeping `docker logs` output through a supervisor log-forwarder.

### Changed

- Supervisor program output for `start.sh`, `watchdog.sh`, and `shutdown.sh` is now captured into the rotating `/data` log file and mirrored back to container stdout/stderr.

## [4.18.0] - 2026-05-07

### Added

- Added post-rotation restart controls for `rotate_on_poor_speed.sh`: `ROTATE_POST_ROTATION_ACTION=watchdog-exit` and `ROTATE_RESTART_REQUEST_FILE` to request a controlled watchdog exit after successful profile rotation.
- Added watchdog handling for rotation restart requests with `ROTATE_RESTART_EXIT_DELAY` before exit.

## [4.17.0] - 2026-05-07

### Added

- Added bundled helper `data/scripts/rotate_on_poor_speed.sh` for adaptive profile rotation based on poor speed/latency streaks with cooldown control, supporting WireGuard/OpenVPN modes and optional NordVPN refresh before WireGuard rotation.

### Changed

- Documented adaptive profile rotation workflow and variables in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.16.2] - 2026-05-07

### Fixed

- Made `upgrade_check.sh` tolerant of GitHub/DNS/network lookup failures: it now warns and exits successfully after local checks instead of failing hard.

## [4.16.1] - 2026-05-07

### Fixed

- Extended `upgrade_check.sh` to also report NZBGet application version drift against remote stable/testing metadata from `README.md`, not only the image/codebase version.

## [4.16.0] - 2026-05-07

### Added

- Added bundled helper `data/scripts/upgrade_check.sh` to perform a simple pre-update check: compare local vs remote image/codebase version metadata and print relevant changelog impact before updating.

### Changed

- Documented `upgrade_check.sh` usage in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.15.1] - 2026-05-07

### Changed

- Clarified `log_sanitizer.sh` execution context in docs: preferred usage is inside the container (`/data/scripts/log_sanitizer.sh`), with optional host-side invocation when `/data` is bind-mounted.

## [4.15.0] - 2026-05-07

### Added

- Added bundled helper `data/scripts/log_sanitizer.sh` to sanitize logs before sharing by redacting common tokens/secrets, IP addresses, and absolute paths.

### Changed

- Documented log-sanitizer usage in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.14.0] - 2026-05-07

### Added

- Added `VPN_FAILSAFE_NZBGET_ACTION` in `run/nobody/watchdog.sh` to trigger app-level NZBGet fail-safe behavior after unhealthy threshold: `none` (default), `pause` (`nzbget -P`), or `stop` (`nzbget -Q`).

### Changed

- Watchdog now applies the NZBGet fail-safe once per unhealthy period and resets the fail-safe guard when VPN IP is detected again.
- Clarified README behavior after VPN recovery: `stop` auto-starts NZBGet again when tunnel IP returns, while `pause` keeps downloads paused until manual resume.

## [4.13.3] - 2026-05-07

### Changed

- Added a startup info log in `watchdog.sh` when `BACKUP_CRON_SCHEDULE` is configured, showing active backup scheduler settings (`BACKUP_CRON_SCHEDULE`, `BACKUP_CRON_SCRIPT`, `BACKUP_CRON_SCRIPT_TIMEOUT`).

## [4.13.2] - 2026-05-07

### Changed

- Added complete `docker-compose.yml` examples (with remarks) to `data/scripts/README.md` for WireGuard rotation + backups, OpenVPN rotation + transition notifications, and NordVPN refresh + unhealthy handling.

## [4.13.1] - 2026-05-07

### Changed

- Expanded `data/scripts/README.md` with detailed usage examples for each bundled helper script, including manual execution, scheduler hooks, unhealthy hooks, and notification hook configurations.

## [4.13.0] - 2026-05-07

### Changed

- `VPN_SELFTEST_STATUS_FILE` JSON output now includes timezone-aware `timestamp` and `timestamp_tz` fields controlled by `NZBGETVPN_TIMESTAMP_TZ`, while keeping legacy `timestamp_utc` for compatibility.
- Updated README documentation to describe timezone handling for ready file, self-test status JSON, and backup timestamps.

## [4.12.0] - 2026-05-07

### Added

- Added `NZBGETVPN_TIMESTAMP_TZ` (`utc` or `local`) to control timezone mode for generated timestamps used by `VPN_SELFTEST_READY_FILE` and `data/scripts/backup_config.sh`.

### Changed

- Ready-file and backup timestamp documentation now describes timezone selection behavior instead of UTC-only output.

## [4.11.0] - 2026-05-07

### Added

- Dedicated notification variables for self-test transitions and unhealthy events: `NOTIFY_SELFTEST_STATE_SCRIPT`, `NOTIFY_SELFTEST_STATE_TIMEOUT`, `NOTIFY_UNHEALTHY_SCRIPT`, and `NOTIFY_UNHEALTHY_TIMEOUT`.
- Watchdog support for `NOTIFY_UNHEALTHY_SCRIPT` as a notification path independent from `VPN_UNHEALTHY_ACTION`.

### Changed

- Reorganized environment-variable documentation so backup scheduling/retention variables are grouped in a single overview section (`Scheduled Config Backups`) instead of being split across multiple sections.
- Removed duplicated self-test behavior paragraphs in `README.md` to improve readability.
- Notification documentation now points to dedicated `NOTIFY_*` variables while keeping legacy `VPN_SELFTEST_STATE_HOOK*` compatibility in runtime behavior.

## [4.10.0] - 2026-05-07

### Added

- Added dedicated backup scheduler variables in watchdog: `BACKUP_CRON_SCHEDULE`, `BACKUP_CRON_SCRIPT` (default `/data/scripts/backup_config.sh`), and `BACKUP_CRON_SCRIPT_TIMEOUT`.

### Changed

- Automatic config backups are now scheduled independently from `VPN_CRON_*`; backup documentation examples now use `BACKUP_CRON_*`.

## [4.9.0] - 2026-05-07

### Added

- Added bundled automatic config-backup helper script `data/scripts/backup_config.sh` for scheduled or unhealthy-hook usage.
- Added `/data/backups` as a default managed data directory with bundled README template.

### Changed

- Config-backup defaults now target `/data/backups`, and the backup script creates the destination path automatically when it does not exist.
- Documented automatic config-backup usage and variables in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.8.1] - 2026-05-07

### Changed

- Added explicit environment-variable examples in `README.md` for `notify_discord.sh`, `notify_telegram.sh`, and `notify_pushover.sh`.

## [4.8.0] - 2026-05-07

### Added

- Added bundled notification helper examples in `data/scripts/`: `notify_discord.sh`, `notify_telegram.sh`, and `notify_pushover.sh`, designed for `VPN_SELFTEST_STATE_HOOK` and `VPN_UNHEALTHY_SCRIPT` usage.

### Changed

- Documented notification-helper configuration and usage in `README.md`, `README-containers.md`, and `data/scripts/README.md`.

## [4.7.5] - 2026-05-07

### Changed

- Clarified notification guidance in the self-test/healthcheck documentation: Discord/Telegram/Pushover integrations are not built in, but can be implemented cleanly via `VPN_SELFTEST_STATE_HOOK` state transitions (`ready` -> `not_ready`) or `VPN_UNHEALTHY_SCRIPT`.

## [4.7.4] - 2026-05-07

### Changed

- Removed the optional DNS leak check from `run/nobody/vpn-selftest.sh` and removed its related environment variables (`VPN_SELFTEST_DNS_LEAK_TEST`, `VPN_SELFTEST_DNS_LEAK_STRICT`, `VPN_SELFTEST_DNS_LEAK_TIMEOUT`).

### Fixed

- Removed `tcpdump` from the image package list because it is no longer required by self-test logic.

## [4.7.2] - 2026-05-07

### Changed

- Changed self-test runtime defaults from `/tmp` to `/data` for `VPN_SELFTEST_DEBOUNCE_FILE` and `VPN_SELFTEST_STATE_FILE` (`/data/nzbgetvpn-selftest-debounce` and `/data/nzbgetvpn-selftest-state`).

## [4.7.1] - 2026-05-07

### Fixed

- Avoided noisy self-test runtime warnings caused by mixed root/nobody ownership in sticky `/tmp`: healthcheck now disables debounce-file side effects, and watchdog self-test falls back to per-UID default state/debounce filenames when the shared default file exists but is not writable.

## [4.6.1] - 2026-05-07

### Changed

- Added Docker Compose orchestration examples for health/ready/status/state-hook based workflows.

## [4.6.0] - 2026-05-07

### Added

- Debounce/grace options for self-test readiness: `VPN_SELFTEST_DEBOUNCE_CRIT`, `VPN_SELFTEST_DEBOUNCE_WARN` and `VPN_SELFTEST_DEBOUNCE_FILE` to reduce flapping during transient failures.

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

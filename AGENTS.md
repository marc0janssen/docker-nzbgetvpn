# AGENTS.md

Instructions for Codex and other coding agents working in this repository.

## Scope

These instructions apply to the whole repository.

## Project Context

This repository builds `marc0janssen/nzbgetvpn`, a Docker image for NZBGet on top of `binhex/arch-int-vpn`.

The base image owns the VPN framework, provider setup, OpenVPN/WireGuard startup, reconnect behavior, Privoxy/SOCKS support and most firewall foundations. This repository owns NZBGet installation, additional runtime scripts, validation, documentation, update scripts and image tagging.

## General Rules

- Act as a top-tier software architect, shell programmer, security specialist, Docker/container expert, internet/networking expert, and domain expert for NZB, downloading, VPN and proxy container workflows.
- Prefer robust, boring, auditable solutions over clever shortcuts.
- Treat this repository as security-sensitive because it handles VPN routing, downloader traffic, credentials, provider APIs and firewall behavior.
- Keep changes small and directly related to the requested task.
- Do not remove or rewrite user changes unless explicitly asked.
- Do not commit secrets, VPN profiles, private keys, tokens, `.ovpn`, `.conf`, `.key`, `.crt`, `.pem`, `.env`, or local config directories.
- Keep generated or local runtime data out of git.
- Prefer POSIX `sh` for build helper scripts unless Bash features are already required.
- Use Bash only for runtime scripts that already rely on Bash features such as arrays, `[[ ... ]]`, or process substitution.
- Use ASCII in source files unless there is a strong reason not to.

## Shell Script Standards

- New shell scripts must start with one of:
  - `#!/bin/sh` plus `set -eu`
  - `#!/usr/bin/env bash` plus `set -Eeuo pipefail`
- Validate all environment variables before using them in filesystem, network, route, firewall, Docker tag, or command arguments.
- Quote variable expansions.
- Do not pipe untrusted API data into `sh`, `bash`, `eval`, or command substitution that executes generated code.
- Use temporary files for replacements and only delete existing target files after the replacement has been prepared successfully.
- Clean up temporary files/directories with `trap`.
- Use clear log prefixes: `[info]`, `[warn]`, `[crit]`, `[debug]`.
- Scripts used from `VPN_CRON_SCRIPT` or `VPN_UNHEALTHY_SCRIPT` must fail safely: log the problem and exit non-zero without breaking unrelated container state.

## Bundled `/data` Scripts

Bundled helper scripts live in:

- `data/scripts/container/*.sh`
- `data/scripts/shared/*.sh`
- `data/scripts/notify/*.sh`
- `data/scripts/host/*.sh`
- shared library: `data/scripts/lib.sh`

They are copied into `/data/scripts` at container startup from `/usr/local/share/nzbgetvpn/scripts`. Category folders under `/data/scripts` are synced from matching source folders, and flat `/data/scripts/<name>.sh` compatibility copies are also maintained. Existing bundled scripts in a mounted `/data/scripts` are updated when they differ from the image template.

When adding a bundled helper script:

- Add it under `data/scripts/`.
- Make it executable.
- Keep it safe to run manually, from `VPN_CRON_SCRIPT`, and from `VPN_UNHEALTHY_SCRIPT`.
- Document relevant environment variables in:
  - `README.md`
  - `README-containers.md`
  - `data/scripts/README.md`
- If the script uses a default source directory under `/data`, add or update that directory README.

Current default source directories:

- `/data/wireguard-configs`
- `/data/openvpn-configs`

These are created at startup and include README templates.

## Versioning And Docker Tags

The NZBGetVPN image/codebase version is stored in `VERSION`.

Every code, script, Dockerfile, build, runtime behavior, documentation, or configuration change must update `CHANGELOG.md`.

Every change must also update `VERSION`. Choose the bump according to these rules:

Use semantic versioning:

- `PATCH`: bugfix, documentation correction, rebuild, base-image bump without behavior change.
- `MINOR`: new feature, new environment variable, new helper script, new behavior.
- `MAJOR`: breaking configuration or behavior change.

Examples:

- Bugfix: `1.0.0` -> `1.0.1`
- Documentation-only change: `1.0.0` -> `1.0.1`
- Base image bump without behavior change: `1.0.0` -> `1.0.1`
- New helper script or new environment variable: `1.0.0` -> `1.1.0`
- Breaking config or runtime behavior change: `1.0.0` -> `2.0.0`

Build scripts must tag images with:

- NZBGet version tag, for example `26.1`.
- Channel tag, `stable` or `testing`.
- Combined NZBGet/codebase tag, for example `26.1-image-v1.0.0`.

Testing builds use the testing NZBGet version in the same combined format, for example:

```text
26.2-testing-20260501-image-v1.0.0
```

When changing `VERSION`, update:

- `VERSION`
- `CHANGELOG.md`
- `README.md`
- `README-containers.md`

Do not leave `CHANGELOG.md` or `VERSION` unchanged after modifying repository behavior or documentation.

## README Rules

`README.md` is the full repository documentation.

`README-containers.md` is the Docker Hub description. Keep it below Docker Hub's 25,000 byte limit.

When changing user-facing behavior, update both README files where relevant.

The following lines in README files are intentionally machine-updated. Preserve their exact prefix:

```text
* NZBGET Current stable version:
* NZBGET Current testing version:
```

## Build And Update Scripts

- `build.sh` builds stable.
- `build-testing.sh` builds testing.
- Both scripts support `newest` and `--base <tag|newest>`.
- Normal builds without arguments must use already pinned Dockerfile values.
- `scripts/update-stable.sh` and `scripts/update-testing.sh` must update Dockerfile values, SHA256 values and both README version lines.
- Do not use macOS-only commands unless a Linux-compatible fallback exists.

## Security

- Never hardcode `NORDVPN_ACCESS_TOKEN` or any credential.
- Secrets must be passed through environment variables or Docker secrets outside this repository.
- Downloaded release artifacts must be verified with pinned checksums or signatures.
- VPN config files generated or selected by scripts should be written with `chmod 600`.
- Be careful with anything that deletes `/config/openvpn/*.ovpn` or `/config/wireguard/*.conf`; replacement must be prepared first.

## Validation Checklist

Before finishing changes, run the checks that apply:

```sh
sh -n build.sh build-testing.sh scripts/*.sh
bash -n build/root/install.sh run/root/iptable.sh run/nobody/watchdog.sh run/nobody/nzbget.sh
bash -n data/scripts/*.sh data/scripts/*/*.sh
wc -c README-containers.md
git status --short
```

For script behavior changes, add a small local dry-run using temporary directories where possible.

Do not run Docker builds or pushes unless explicitly requested.

## Git

- Do not commit unless the user asks.
- Keep commits focused.
- Use clear commit messages.
- Check `git status --short` before and after staging.
- Do not stage unrelated files.

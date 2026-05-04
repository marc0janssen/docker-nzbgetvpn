# Security Policy

## Reporting Vulnerabilities

Please do not open public issues with secrets, VPN configs, access tokens, private keys, provider credentials, `.ovpn`, `.conf`, `.key`, `.crt`, `.pem`, `.env` contents or logs that expose those values.

Report vulnerabilities privately through the maintainer contact page:

https://bio.mjanssen.nl/@Marco

Include the affected image tag, NZBGetVPN version, NZBGet version, base image tag, a clear description, reproduction steps and sanitized logs when possible.

## Scope

This repository owns the NZBGet installation layer, runtime scripts, bundled helper scripts, validation, documentation and build/update scripts for `marc0janssen/nzbgetvpn`.

The VPN framework, provider setup, OpenVPN/WireGuard startup, reconnect behavior, Privoxy/SOCKS support and most firewall foundations are inherited from `binhex/arch-int-vpn`. Issues specific to that base image should also be reported upstream. Issues specific to NZBGet itself should be reported to the NZBGet project.

## Handling Secrets

Use environment variables, Docker secrets or your orchestrator's secret store for credentials. Keep local VPN profiles and generated configs out of git. If a secret is exposed, rotate or revoke it with the provider before sharing any sanitized diagnostic details.

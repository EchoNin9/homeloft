# Security policy

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Use GitHub's private reporting
instead: **Security → Report a vulnerability** on this repo. You should get a reply within a
week. Fixes ship on `main` and are noted in the release notes, with credit if you'd like it.

Useful reports name the component (`nas/bridge`, `cloud/lambdas`, `cloud/terraform`, `web`),
the version or commit, and the steps to reproduce.

## Supported versions

Only the latest release on `main` gets fixes. Homeloft is a self-hosted project with no hosted
service, so every deployment is its operator's own. Please update to the latest release before
reporting.

## Scope

In scope: anything in this repo, such as the bridge's command validation, the API's
authorization, the IoT and IAM policies, the OpenTofu module defaults, the web app and the CI
workflows.

Out of scope: vulnerabilities in Home Assistant, Zigbee2MQTT, AdGuard, Synology DSM or AWS
services themselves (please report those upstream), and setups that change the documented
defaults (for example, adding `lock.unlock` to the allowlists).

How the pieces are protected, and which trade-offs are deliberate: [docs/security.md](docs/security.md).

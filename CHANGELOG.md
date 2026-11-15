# Changelog

All notable changes to Homeloft. Versions follow [SemVer](https://semver.org); each one is a
`vX.Y.Z` tag on `main` with a GitHub release ([docs/releasing.md](docs/releasing.md)).

## [Unreleased]

## [0.1.0] - 2026-11-14

First tagged release, after the rename from the project's earlier working name to Homeloft.

- **Rename:** MQTT topic root `homeloft/{homeId}/…`, `homeloft-*` AWS resources, compose project
  `homeloft`, bridge package `homeloft_bridge`.
- **Brand:** a new mark (house, loft window, outbound bird) on the favicon, sign-in page and sidebar.
- **Security:** Content Security Policy and security headers on CloudFront, TOTP MFA on by default,
  API access logs, a read-only Docker socket proxy for monitor/wud, Actions pinned to SHAs,
  dependency audits, gitleaks, CodeQL and Dependabot. See [docs/security.md](docs/security.md).
- **Docs:** the Quickstart (replacing first-deploy), lessons from a real redeploy (moving an existing
  install, the `wud` folder, TOTP at first sign-in) and the security model.
- **Deploy:** the bundled deploy workflow is opt-in (`AWS_DEPLOY_ROLE_ARN`) and keeps plan output out of logs.

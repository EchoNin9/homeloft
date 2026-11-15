# Changelog

All notable changes to Homeloft. Versions follow [SemVer](https://semver.org); each one is a
`vX.Y.Z` tag on `main` with a GitHub release ([docs/releasing.md](docs/releasing.md)).

## [Unreleased]

## [0.2.0] - 2026-11-15

Frontend platform upgrade. No contract, API, cloud or bridge behaviour changes.

- **Web:** React 19.3 and TypeScript 7 (the native compiler). No code changes were needed; the dashboard was checked by hand
  (toggles, brightness, colour, thermostat, history, search, failing-command rollback) with a clean console under StrictMode.
  The bundle is about 23 kB larger gzipped (React 19). Embedding hosts on React 18 still work.
- **Upgrading:** the bridge only changes its version string. Redeploy the cloud (which republishes the web app); rebuilding the bridge is optional.

## [0.1.2] - 2026-11-15

- **Bridge:** sends a fresh snapshot when Home Assistant fires `homeassistant_started`. A bridge that connects while
  HA is still booting no longer stays stuck on a near-empty entity list until it's restarted.
- **Docs:** Quickstart covers the socket proxy (port 2375) and embedding under a CSP; the Upgrading steps work on DSM
  (legacy builder); the module `?ref=` pins in the docs now follow `bump-version.sh`.

## [0.1.1] - 2026-11-15

Maintenance release: docs site, live demo and dependency updates. No contract or API changes.

- **Docs:** house-style README, new Architecture, Configuration, Upgrading and Troubleshooting pages,
  CONTRIBUTING and Code of Conduct. Published at [homeloft.dev](https://homeloft.dev) (Starlight, from `docs/`).
- **Demo:** `npm run build:demo` builds the dashboard with an in-browser fake API, live at
  [homeloft.dev/demo](https://homeloft.dev/demo/).
- **Bridge:** Python 3.15 base image; paho-mqtt 2.2.0, websockets 17.4. Rebuild the bridge on the NAS
  ([Upgrading](docs/upgrading.md)).
- **NAS images:** AdGuard Home v0.107.80, Zigbee2MQTT 2.14.3, WUD 9.8.0, docker-socket-proxy v0.5.0
  (`POST=0` still blocks every non-GET request, including the new pause/unpause endpoints).
- **CI:** Actions bumped (still pinned to commit SHAs; the CodeQL pin now points at the commit, not the tag
  object), bridge tests on Python 3.15, branch rulesets require the `site` and `secrets` checks too.

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

# Contributing

Thanks for helping. Homeloft is small on purpose, so the best contributions are fixes, clearer docs
and new Synology gotchas. Please open an issue to discuss a new feature before writing it.

## Ground rules

- **Branches:** `main` is production and only accepts merges from `develop`. Branch off `develop` and
  open your PR against **`develop`**.
- **Contract first:** [docs/contract.md](docs/contract.md) defines every MQTT topic, payload, table item and
  API route. Change it in the same PR as the code, and keep `/v1` changes additive.
- **Security defaults stay safe:** never add `lock.unlock`, alarms, scripts or `update.install` to a default
  allowlist. See the [security model](docs/security.md).
- **No new runtime dependencies** without a reason in the PR. The Lambdas use boto3 only and
  `web/src/client` uses nothing.
- **Found a DSM quirk?** Add it to [Synology gotchas](docs/synology.md#synology-gotchas) in the same PR.
- Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Running the tests

CI runs all of these on every PR.

| Part | Command |
|---|---|
| Bridge | `cd nas/bridge && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-dev.txt && .venv/bin/python -m pytest -q` |
| Cloud | `cd cloud && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest -q` |
| OpenTofu | `tofu fmt -check -recursive cloud/terraform`, then `tofu init -backend=false && tofu validate` in each stack |
| Web | `cd web && npm ci && npm run typecheck && npm run build && npm test -- --run` |
| Docs site | `cd site && npm ci && npm test && npm run build` |

## Working on the UI without AWS

`cd web && npm run dev:mock` serves the dashboard with a fake API: sample lights, a thermostat, covers,
scenes, sensors, a bulb that always fails and an offline second home. `npm run build:demo` builds the same
thing as static files, which is what [homeloft.dev/demo](https://homeloft.dev/demo/) serves.

## Docs

The docs are plain markdown in [`docs/`](docs/), readable on GitHub. The site at
[homeloft.dev](https://homeloft.dev) is built from them by `site/` (Starlight): `cd site && npm run dev`.
Start each page with one `# Title` line and use relative `.md` links; the build turns them into site links.

## Using a coding agent

Agents read [CLAUDE.md](CLAUDE.md) (also `AGENTS.md`). The same rules apply to their PRs.

By contributing you agree that your work is released under the [MIT License](LICENSE) and that you
follow the [Code of Conduct](CODE_OF_CONDUCT.md).

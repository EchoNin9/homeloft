# Releasing

A release is a `vX.Y.Z` tag on `main`. Pushing the tag runs `.github/workflows/release.yml`, which
checks that the versions agree and publishes a GitHub release with the CHANGELOG section as its notes.
Deployments pick a tag (see your deploy workflow's `ref` input).

1. On a branch off `develop`: `./scripts/bump-version.sh X.Y.Z`, then move the `[Unreleased]` notes in
   `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`. Open a PR into `develop` and merge it when green.
2. Promote `develop` → `main` by PR.
3. Tag the promoted commit and push the tag:
   ```sh
   git fetch origin && git tag -a vX.Y.Z origin/main -m "vX.Y.Z" && git push origin vX.Y.Z
   ```
4. The **release** workflow fails if the tag isn't on `main`, a version string disagrees, or the
   CHANGELOG has no section for it. Fix it on `develop`, promote, delete the tag and tag again.

SemVer: bump **major** for a breaking change to `docs/contract.md` (topics, payloads, table items)
or anything else that needs bridge and cloud upgraded together; **minor** for features; **patch** for fixes.
Bridge and cloud share one version, and the API reports it at `/v1/health`.

#!/usr/bin/env bash
# Set the release version everywhere it lives:  ./scripts/bump-version.sh 0.2.0
# Then add a "## [0.2.0] - YYYY-MM-DD" section to CHANGELOG.md (docs/releasing.md).
set -euo pipefail
v="${1:?usage: $0 X.Y.Z}"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not X.Y.Z: $v" >&2; exit 1; }
cd "$(dirname "$0")/.."
sed -i.bak -E "s/^(  \"version\": )\"[^\"]+\"/\1\"$v\"/" web/package.json
sed -i.bak -E "s/^__version__ = \"[^\"]+\"/__version__ = \"$v\"/" nas/bridge/homeloft_bridge/__init__.py
sed -i.bak -E "s/(image: homeloft-bridge:)[0-9.]+/\1$v/" nas/docker-compose.yml
sed -i.bak -E "s/(API_VERSION += )\"[^\"]+\"/\1\"$v\"/" cloud/terraform/modules/homeloft/lambdas.tf
# module source pins shown to users (docs + example), so copy-paste gets the current release
sed -i.bak -E "s/(modules\/homeloft\?ref=v)[0-9.]+/\1$v/" docs/integrate.md cloud/terraform/examples/existing-cognito/main.tf
rm -f docs/integrate.md.bak cloud/terraform/examples/existing-cognito/main.tf.bak
rm -f web/package.json.bak nas/bridge/homeloft_bridge/__init__.py.bak nas/docker-compose.yml.bak cloud/terraform/modules/homeloft/lambdas.tf.bak
(cd web && npm version "$v" --no-git-tag-version --allow-same-version >/dev/null)   # keeps package-lock.json in step
./scripts/check-version.sh "$v"

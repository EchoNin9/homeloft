#!/usr/bin/env bash
# Fail unless every version string (and the CHANGELOG) says X.Y.Z:  ./scripts/check-version.sh 0.2.0
set -euo pipefail
v="${1:?usage: $0 X.Y.Z}"
cd "$(dirname "$0")/.."
bad=0
check() { grep -qE "$2" "$1" || { echo "$1: expected $v" >&2; bad=1; }; }
check web/package.json "^  \"version\": \"$v\""
check nas/bridge/homeloft_bridge/__init__.py "^__version__ = \"$v\""
check nas/docker-compose.yml "image: homeloft-bridge:$v\$"
check cloud/terraform/modules/homeloft/lambdas.tf "API_VERSION += \"$v\""
check CHANGELOG.md "^## \[$v\]"
[ "$bad" = 0 ] && echo "version $v: ok"
exit "$bad"

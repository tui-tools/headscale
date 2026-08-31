#!/usr/bin/env bash
# Vendor the headscale source at the pinned version into src/, then verify the
# checkout is exactly the upstream tag. The build compiles THIS source; nothing
# downloads a prebuilt upstream binary. Run by CI before goreleaser, and locally
# to reproduce a build.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$here/VERSION")"   # e.g. v0.29.3
repo="${HEADSCALE_REPO:-https://github.com/juanfont/headscale.git}"
dest="$here/src"

rm -rf "$dest"
git clone --quiet --depth 1 --branch "$version" "$repo" "$dest"

# Prove the checkout is the tag we pinned, not a moved branch: the resolved
# commit must be the one the tag points at on the remote.
cd "$dest"
local_sha="$(git rev-parse HEAD)"
remote_sha="$(git ls-remote "$repo" "refs/tags/$version^{}" | awk '{print $1}')"
[ -z "$remote_sha" ] && remote_sha="$(git ls-remote "$repo" "refs/tags/$version" | awk '{print $1}')"
if [ "$local_sha" != "$remote_sha" ]; then
  echo "vendor: checkout $local_sha != upstream tag $version ($remote_sha)" >&2
  exit 1
fi
echo "vendored headscale $version at $local_sha"

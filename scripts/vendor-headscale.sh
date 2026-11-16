#!/usr/bin/env bash
# Vendor the headscale source at the pinned version into src/, then verify the
# checkout is exactly the pinned upstream commit. The build compiles THIS
# source; nothing downloads a prebuilt upstream binary. Run by CI before
# goreleaser, and locally to reproduce a build.
#
# Two files pin the source, and both are reviewed in the bump PR:
#   VERSION          the upstream tag (e.g. v0.29.7), which names the release
#                    and is what headscale's version stamp reports;
#   UPSTREAM_COMMIT  the full commit SHA that tag pointed at when the bump was
#                    reviewed.
# A tag is a movable name. Comparing the clone with `git ls-remote` of the same
# repository only proves the tag points where it points now, so a tag moved
# after review would be built and released. The commit SHA is the independent
# pin: if the tag no longer resolves to it, the vendor step fails and nothing
# is built.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$here/VERSION")"            # e.g. v0.29.7
pinned_sha="$(tr -d '[:space:]' < "$here/UPSTREAM_COMMIT")"  # 40 hex digits
repo="${HEADSCALE_REPO:-https://github.com/juanfont/headscale.git}"
dest="${HEADSCALE_DEST:-$here/src}"

if ! [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "vendor: VERSION '$version' is not an upstream release tag" >&2
  exit 1
fi
if ! [[ "$pinned_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "vendor: UPSTREAM_COMMIT must be a full 40-character commit SHA" >&2
  exit 1
fi

rm -rf "$dest"
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" "$repo" "$dest"

cd "$dest"
local_sha="$(git rev-parse HEAD)"

# The checkout must be the commit the bump PR pinned. This is the check that
# a moved tag cannot pass.
if [ "$local_sha" != "$pinned_sha" ]; then
  echo "vendor: upstream tag $version now resolves to $local_sha," >&2
  echo "vendor: but UPSTREAM_COMMIT pins $pinned_sha. The tag moved after the" >&2
  echo "vendor: bump was reviewed; refusing to build. Review the new commit and" >&2
  echo "vendor: update UPSTREAM_COMMIT in a PR if it is legitimate." >&2
  exit 1
fi

# And the tag on the remote must still point there, so the release is not built
# from a commit the tag has since left (a clone served from a stale mirror, for
# instance).
remote_sha="$(git ls-remote "$repo" "refs/tags/$version^{}" | awk '{print $1}')"
[ -z "$remote_sha" ] && remote_sha="$(git ls-remote "$repo" "refs/tags/$version" | awk '{print $1}')"
if [ "$remote_sha" != "$pinned_sha" ]; then
  echo "vendor: upstream tag $version is $remote_sha on the remote, UPSTREAM_COMMIT pins $pinned_sha" >&2
  exit 1
fi
echo "vendored headscale $version at $local_sha (pinned)"

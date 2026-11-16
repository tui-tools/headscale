#!/usr/bin/env bash
# Exercise scripts/vendor-headscale.sh against a throwaway local "upstream"
# repository, so the pin is tested without the network: the pinned commit is
# vendored, a tag moved to another commit is refused, and a VERSION or
# UPSTREAM_COMMIT of the wrong shape is refused before anything is cloned.
#
#   scripts/test-vendor.sh
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A copy of the repo's scripts with its own VERSION and UPSTREAM_COMMIT, so the
# test never edits the real pins.
mkdir -p "$work/mirror/scripts"
cp "$here/scripts/vendor-headscale.sh" "$work/mirror/scripts/"

upstream="$work/upstream"
git init --quiet "$upstream"
git -C "$upstream" -c user.name=t -c user.email=t@example.invalid \
  commit --quiet --allow-empty -m first
first="$(git -C "$upstream" rev-parse HEAD)"
git -C "$upstream" tag v9.9.9
git -C "$upstream" -c user.name=t -c user.email=t@example.invalid \
  commit --quiet --allow-empty -m second
second="$(git -C "$upstream" rev-parse HEAD)"

run() {
  HEADSCALE_REPO="file://$upstream" HEADSCALE_DEST="$work/src" \
    bash "$work/mirror/scripts/vendor-headscale.sh" >"$work/out" 2>&1
}
fail() { echo "FAIL: $*" >&2; cat "$work/out" >&2; exit 1; }

printf 'v9.9.9\n' > "$work/mirror/VERSION"
printf '%s\n' "$first" > "$work/mirror/UPSTREAM_COMMIT"
run || fail "the pinned commit was not vendored"
[ "$(git -C "$work/src" rev-parse HEAD)" = "$first" ] || fail "vendored the wrong commit"
echo "ok: the pinned commit is vendored"

# Move the tag to another commit, the way a compromised or rewritten upstream
# would. The pin has not changed, so the build must stop.
git -C "$upstream" tag -f v9.9.9 "$second" >/dev/null
if run; then fail "a moved tag was vendored"; fi
grep -q "tag moved" "$work/out" || fail "the refusal does not say the tag moved"
echo "ok: a moved tag is refused"

printf '%s\n' "${first:0:12}" > "$work/mirror/UPSTREAM_COMMIT"
if run; then fail "an abbreviated SHA was accepted"; fi
echo "ok: an abbreviated SHA is refused"

printf '%s\n' "$first" > "$work/mirror/UPSTREAM_COMMIT"
printf 'main\n' > "$work/mirror/VERSION"
if run; then fail "a branch name was accepted as VERSION"; fi
echo "ok: a VERSION that is not a release tag is refused"

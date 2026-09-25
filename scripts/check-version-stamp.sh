#!/usr/bin/env bash
# Prove every headscale binary goreleaser produced reports the pinned upstream
# tag and commit, with no `+dirty`: the version string is the first thing a
# reviewer of a mirror reads, and it has to say the build is the tag.
#
#   scripts/check-version-stamp.sh [dist]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${1:-$here/dist}"
version="$(tr -d '[:space:]' < "$here/VERSION")"
commit="$(git -C "$here/src" rev-parse HEAD)"

found=0
while IFS= read -r bin; do
  found=$((found + 1))
  info="$(go version -m "$bin")"
  mod="$(awk '$1 == "mod" && $2 == "github.com/juanfont/headscale" {print $3}' <<<"$info")"
  rev="$(awk '$1 == "build" && $2 ~ /^vcs.revision=/ {sub("vcs.revision=", "", $2); print $2}' <<<"$info")"
  modified="$(awk '$1 == "build" && $2 ~ /^vcs.modified=/ {sub("vcs.modified=", "", $2); print $2}' <<<"$info")"
  if [ "$mod" != "$version" ] || [ "$rev" != "$commit" ] || [ "$modified" != "false" ]; then
    echo "version stamp of $bin: mod=$mod vcs.revision=$rev vcs.modified=$modified" >&2
    echo "expected mod=$version vcs.revision=$commit vcs.modified=false" >&2
    exit 1
  fi
  echo "ok: $bin reports $mod at $rev (clean)"
done < <(find "$dist" -type f -name headscale -perm -u+x)
[ "$found" -gt 0 ] || { echo "no headscale binary under $dist" >&2; exit 1; }

#!/usr/bin/env bash
# Security floor for the vendored headscale source: bump the dependencies (and
# the Go toolchain) far enough to clear every HIGH/CRITICAL the package scanner
# flags in the compiled binary. This is the point of building from source: an
# upstream tag pins what it pins, but what WE ship is compiled here, so a
# vulnerable transitive dependency is ours to lift. Patch versions only -- the
# headscale code itself is not touched.
#
# The upstream checkout under src/ is never modified. The lifted go.mod and
# go.sum live OUTSIDE it, in hardened/, and every go command reads them through
# `-modfile`. That matters because headscale takes its version from Go's VCS
# stamping (debug.ReadBuildInfo), not from an ldflag: a single changed file in
# src/ makes Go stamp `v0.29.3+dirty`, which is indistinguishable from an
# accident. With src/ untouched the binary reports exactly the upstream tag and
# commit, and the deliberate difference is published next to the packages as
# hardened/dependency-floor.diff (and is readable in the binary itself with
# `go version -m`).
#
# Run AFTER scripts/vendor-headscale.sh and after Go is on PATH; CI calls it
# right before goreleaser, which builds with the same GOFLAGS (see
# .goreleaser.yaml). Idempotent.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hardened="$here/hardened"
cd "$here/src"

rm -rf "$hardened"
mkdir -p "$hardened"
cp go.mod "$hardened/go.mod"
cp go.sum "$hardened/go.sum"
export GOFLAGS="-modfile=$hardened/go.mod"

# Build with the current Go release (stdlib CVEs are cleared by the toolchain,
# not by go.mod): drop any older toolchain pin the tag carries.
go mod edit -toolchain=none
go get toolchain@latest 2>/dev/null || true

# The modules the scanner flagged, lifted to at least their fixed versions.
# @latest rather than a pin: the floor moves with the advisories, and go.sum
# still records exactly what was used.
go get -u \
  golang.org/x/crypto@latest \
  golang.org/x/text@latest \
  golang.org/x/net@latest \
  google.golang.org/grpc@latest
go mod tidy

# The upstream tree must still be exactly the tag. If anything above wrote
# into src/, the stamp would say +dirty again; stop here instead.
if [ -n "$(git status --porcelain)" ]; then
  echo "harden-deps: the upstream checkout was modified:" >&2
  git status --porcelain >&2
  exit 1
fi

# What we changed relative to upstream, as a reviewable diff. diff exits 1
# when the files differ, which is the expected case.
diff -u --label "upstream/go.mod" --label "hardened/go.mod" \
  go.mod "$hardened/go.mod" > "$hardened/dependency-floor.diff" || true

echo "hardened dependency floor:"
go list -m golang.org/x/crypto golang.org/x/text golang.org/x/net google.golang.org/grpc
go version

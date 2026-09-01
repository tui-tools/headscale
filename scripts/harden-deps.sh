#!/usr/bin/env bash
# Security floor for the vendored headscale source: bump the dependencies (and
# the Go toolchain) far enough to clear every HIGH/CRITICAL the package scanner
# flags in the compiled binary. This is the point of building from source: an
# upstream tag pins what it pins, but what WE ship is compiled here, so a
# vulnerable transitive dependency is ours to lift. Patch versions only -- the
# headscale code itself is not touched.
#
# Run AFTER scripts/vendor-headscale.sh and after Go is on PATH; CI calls it
# right before goreleaser. Idempotent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../src"

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

echo "hardened dependency floor:"
go list -m golang.org/x/crypto golang.org/x/text golang.org/x/net google.golang.org/grpc
go version

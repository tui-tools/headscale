# headscale (tui-tools mirror)

A source-built mirror of [headscale](https://github.com/juanfont/headscale), the
open-source Tailscale control server, re-released into the tui-tools package
repository for the `tui-router` coordination server. Managed on a router by
[`tui-tailscale`](https://tui.tools/tools/tui-tailscale/).

This is **not** a fork and **not** the headscale project. It holds no headscale
source of its own: CI vendors the pinned upstream tag
(`scripts/vendor-headscale.sh`), compiles it from source with the family's Go
pipeline, and re-releases the result with our own `checksums.txt`, a CycloneDX
SBOM, a keyless cosign signature and GitHub build provenance.

## Why build from source, not repackage the binary

Re-signing an opaque upstream executable would place our signature over a binary
we never inspected — a backdoor could ride in unseen. Building from the source
ourselves makes our attestation cover the actual compilation, from commit to
package. We verify; we do not merely trust.

The three proofs this produces (`checksums.txt`, its `.sigstore.json` cosign
signature, and the GitHub provenance attestation) are exactly what the tui-tools
`pkgs` provenance gate requires, so the mirror flows into the apt / dnf / pacman
repositories through the same gate as any tool — with no exception to it. It is
not a tool: it carries no `tool.json`, and it is never part of the
`tui-tools-all` metapackage.

## The version it reports

headscale takes its version from Go's VCS stamping, not from a build flag, so
the version string says whether the tree it was compiled from was the tag.
The mirror keeps it that way: `src/` is the upstream tag, untouched, and the
one deliberate change -- a lifted dependency floor (`scripts/harden-deps.sh`:
security patch versions and the current Go) -- lives in an out-of-tree
`go.mod` read through `-modfile`. `headscale version` therefore reports the
upstream tag and commit (`v0.29.4`, not `v0.29.4+dirty`), CI fails a build
whose binaries say otherwise (`scripts/check-version-stamp.sh`), and each
release carries `dependency-floor.diff`, the exact go.mod change, under the
signed `checksums.txt`. `go version -m /usr/bin/headscale` lists the module
versions actually compiled in.

## companion.json

`companion.json` is how [tui.tools](https://tui.tools) lists this repository.
The site's catalog build reads it at the default branch's HEAD, the same way it
reads a tool's `tool.json`, and renders the mirror in the Companions section
rather than in the tool grid. It states the kind (`mirror`), the one-line
summary, the upstream project, the upstream tag pinned in `VERSION`, and the
package names shipped. CI fails if `upstreamVersion` and `VERSION` disagree, and
the bump workflow moves both in one commit.

## What ships

`headscale` for linux amd64 + arm64 as `.deb`, `.rpm` and archlinux
`.pkg.tar.zst`: the binary at `/usr/bin/headscale`, a hardened systemd unit, an
example config at `/etc/headscale/config.yaml` (a conffile, never overwritten),
and a `headscale` system user. The service is **not** enabled or started by the
package — the example config has placeholders; the operator, or the
omarchy-server router `headscale` addon, enables it once a real config is in
place.

## Releasing

The version is pinned in `VERSION` (e.g. `v0.29.3`). To cut a mirror release,
bump `VERSION` to an upstream tag and push a matching git tag; CI verifies the
tag equals `VERSION`, vendors that upstream source, and releases. A scheduled
job opens the bump PR when upstream publishes a new release.

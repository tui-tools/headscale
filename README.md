# headscale (tui-tools mirror)

A source-built mirror of [headscale](https://github.com/juanfont/headscale), the
open-source Tailscale control server, re-released into the tui-tools package
repository for the `tui-router` coordination server. Managed on a router by
`tui-vpn`.

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

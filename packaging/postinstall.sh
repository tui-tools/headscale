#!/bin/sh
# Cross-distro postinstall for the tui-tools headscale mirror (deb/rpm/archlinux).
# Creates the system user the unit runs as; does NOT enable or start the service
# -- the shipped config is an example with placeholders, so the operator (or the
# omarchy-server router addon) enables headscale once a real config is in place.
set -e
groupadd --force --system headscale 2>/dev/null || groupadd -r headscale 2>/dev/null || true
if ! id -u headscale >/dev/null 2>&1; then
  useradd --system --shell /usr/sbin/nologin --gid headscale \
    --home-dir /var/lib/headscale --comment "headscale default user" headscale 2>/dev/null || \
  useradd -r -s /usr/sbin/nologin -g headscale -d /var/lib/headscale headscale 2>/dev/null || true
fi
[ -d /var/lib/headscale ] && chown headscale:headscale /var/lib/headscale 2>/dev/null || true
if [ -d /run/systemd/system ]; then systemctl daemon-reload >/dev/null 2>&1 || true; fi

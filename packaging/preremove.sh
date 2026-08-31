#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then systemctl stop headscale.service >/dev/null 2>&1 || true; fi

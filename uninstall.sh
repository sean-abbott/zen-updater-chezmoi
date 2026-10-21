#!/bin/sh
# Removes everything this repo installs. Run directly from wherever you
# cloned this repo (it doesn't need to be applied via chezmoi first).
set -eu

systemctl --user disable --now zen-updater-check.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/zen-updater-check.service"
rm -f "$HOME/.config/systemd/user/zen-updater-check.timer"
rm -f "$HOME/.local/bin/zen"
rm -f "$HOME/.local/share/applications/zen.desktop"
rm -rf "$HOME/.local/opt/zen-browser"
systemctl --user daemon-reload 2>/dev/null || true

echo "Removed. This script and the chezmoi source directory it came from"
echo "are left in place -- remove the clone yourself if you're done with"
echo "it entirely."

#!/usr/bin/env bash
# Removes disk-guard. Keeps your config and log unless you pass --purge.
set -euo pipefail

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now disk-guard-check.timer disk-guard-daily.timer 2>/dev/null || true
rm -f "$unit_dir"/disk-guard-check.{service,timer} "$unit_dir"/disk-guard-daily.{service,timer}
for dropin in "$unit_dir"/*.d/disk-guard-keep-alive.conf; do
  [[ -e "$dropin" ]] || continue
  rm -f "$dropin"
  rmdir --ignore-fail-on-non-empty "$(dirname "$dropin")"
  echo "removed $dropin"
done
rm -f "$HOME/.local/bin/disk-guard"
systemctl --user daemon-reload

if [[ "${1:-}" == --purge ]]; then
  rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/disk-guard" "${XDG_STATE_HOME:-$HOME/.local/state}/disk-guard"
  echo "removed config and log"
fi
echo "disk-guard is uninstalled"

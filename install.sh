#!/usr/bin/env bash
# Installs disk-guard for the current user. No root needed.
#
#   ./install.sh                         install the script and both timers
#   ./install.sh --keep-alive foo.service   also make systemd never give up on foo.service
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/.local/bin"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/disk-guard"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
keep_alive=()

while (($# > 0)); do
  case "$1" in
    --keep-alive)
      [[ -n "${2:-}" ]] || { echo "--keep-alive needs a unit name" >&2; exit 2; }
      keep_alive+=("$2")
      shift 2
      ;;
    -h | --help)
      sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "systemd --user is not running. On WSL, add this to /etc/wsl.conf and restart WSL:" >&2
  printf '  [boot]\n  systemd=true\n' >&2
  exit 1
fi

install -Dm755 "$here/bin/disk-guard" "$bin_dir/disk-guard"
echo "installed $bin_dir/disk-guard"

if [[ -f "$config_dir/config" ]]; then
  echo "kept existing $config_dir/config"
else
  install -Dm644 "$here/config.example" "$config_dir/config"
  echo "created $config_dir/config (edit it to turn on the emergency clean)"
fi

mkdir -p "$unit_dir"
for f in disk-guard-check.service disk-guard-check.timer disk-guard-daily.service disk-guard-daily.timer; do
  install -m644 "$here/systemd/$f" "$unit_dir/$f"
done
echo "installed timers in $unit_dir"

for unit in "${keep_alive[@]}"; do
  install -Dm644 "$here/systemd/keep-alive.conf" "$unit_dir/$unit.d/disk-guard-keep-alive.conf"
  echo "installed keep-alive drop-in for $unit"
done

systemctl --user daemon-reload
systemctl --user enable --now disk-guard-check.timer disk-guard-daily.timer
echo
systemctl --user list-timers 'disk-guard-*' --no-pager
echo
echo "Next: run 'disk-guard notify-test', then 'disk-guard report'."

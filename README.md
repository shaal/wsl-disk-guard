# wsl-disk-guard

A small bash script that keeps a WSL2 (or any systemd Linux) disk from filling up without warning.

- It warns you before the disk is full, with a Windows notification.
- It deletes caches that are safe to lose when space gets critical.
- It tells you when a background service is down or in a crash loop.

It is a plain script that runs from two systemd user timers. It makes no network calls and needs no root.

## Why

The WSL2 Linux disk is a `ext4.vhdx` file with a fixed maximum size. Free space on the Windows drive does not help when the virtual disk hits that limit. Docker build caches (for example, one Cargo `target/` volume per branch) can grow by tens of GB a day.

When the disk is full, long-running services crash. systemd retries them a few times, then stops. The service stays down after you free the space, until you restart it by hand.

## What it does

| Part | When | What | Deletes data? |
|---|---|---|---|
| Warn | Every 10 min | Notifies you when free space on a watched mount drops below its warning level. | No |
| Emergency clean | Every 10 min, only below `CRITICAL_GB` | Deletes unused Docker volumes that match `CLEAN_VOLUME_PATTERNS`, biggest first, until `TARGET_GB` is free. | Yes, only volumes you list |
| Daily clean | Once a day | Prunes Docker build cache older than 7 days, untagged images, and your own `/tmp` files not used for 7 days. | Yes, caches and temp files |
| Service watch | Every 10 min | Notifies you when a watched `systemd --user` unit is down or restarts again and again. | No |
| Keep-alive (optional) | Always | A drop-in that makes systemd never give up on a unit. The retry delay grows from 5 s to 2 min. | No |

A notification for the same problem repeats at most once an hour.

## Install

```bash
git clone https://github.com/shaal/wsl-disk-guard.git
cd wsl-disk-guard
./install.sh
disk-guard notify-test
```

To also keep a service alive (it must be a `systemd --user` unit):

```bash
./install.sh --keep-alive my-dev-server.service
```

WSL needs systemd. If `install.sh` says that systemd is not running, add this to `/etc/wsl.conf`, then run `wsl --shutdown` from Windows:

```ini
[boot]
systemd=true
```

## Configure

Edit `~/.config/disk-guard/config`. Refer to [`config.example`](config.example) for all options. The important ones:

```bash
WATCH_MOUNTS="/:50 /mnt/e:20"                    # path:warn_gb
CRITICAL_GB=25                                   # emergency clean starts here
TARGET_GB=80                                     # and stops here
CLEAN_VOLUME_PATTERNS="myproject-target-*"       # empty = never delete volumes
WATCH_SERVICES="my-dev-server.service"
```

On WSL, add the Windows drive that holds `ext4.vhdx` to `WATCH_MOUNTS`. WSL can also fail when that drive is full.

The emergency clean is off until you set `CLEAN_VOLUME_PATTERNS`. Put only caches there, such as build output and package caches. Never put a database volume there.

## Commands

```text
disk-guard check         run the 10-minute check now
disk-guard daily         run the daily clean now
disk-guard report        free space, Docker usage, clean candidates, folder sizes
disk-guard notify-test   show a test notification
disk-guard --dry-run check   log what would be deleted, delete nothing
```

Log: `~/.local/state/disk-guard/disk-guard.log`

## Limits

- After the emergency clean deletes a build-cache volume, the next build that uses it starts from zero.
- A job that writes a lot of data in less than 10 minutes can fill the disk before the next check. Set the warning level high enough to give you time.
- Docker does not delete a volume that a container uses. A build that is running keeps its volume.
- On WSL, the guard only warns about the Windows drive. It does not delete Windows files.
- The `.vhdx` file does not get smaller when you delete files. To give the space back to Windows, turn on sparse mode: `wsl --manage <distro> --set-sparse true`.

## Uninstall

```bash
./uninstall.sh           # keeps config and log
./uninstall.sh --purge   # also removes config and log
```

## License

MIT

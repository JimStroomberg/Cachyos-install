# Target CachyOS Configuration

This document defines the installation state we want the future live-ISO
automation script to produce.

The priority is to stay as close as practical to a supported CachyOS Desktop
installation while keeping the selected two-NVMe Btrfs layout.

Verified against upstream sources on 2026-06-11.

## Installation Model

- Boot mode: UEFI only.
- Partitioning mode: manual/scripted GPT partitioning.
- Boot manager: Limine.
- Root filesystem: multi-device Btrfs.
- Desktop profile: KDE Plasma.
- Initramfs path: CachyOS mkinitcpio/Limine tooling.
- Encryption: none.
- Secure Boot: disabled during installation.
- Hibernate: not configured.

The future script should be run from the CachyOS live ISO, after confirming the
machine is booted in UEFI mode.

The current first-pass script is documented in:

```text
installation/live-iso-installer.md
```

Secure Boot is intentionally post-install work. See:

```text
installation/post-install-secure-boot.md
```

## Firmware Preconditions

- Disable Secure Boot.
- Disable CSM/Legacy boot.
- Boot the CachyOS ISO in UEFI mode.
- Confirm EFI variables are available:

```bash
efibootmgr -v
```

If that reports EFI variables are unsupported, the ISO was not booted in UEFI
mode and installation must stop.

## Disk Selection

Target hardware:

- Disk 1: Samsung 980 Pro 2 TB NVMe connected to CPU PCIe lanes.
- Disk 2: Samsung 980 Pro 2 TB NVMe connected through chipset/southbridge.

The final script must not blindly trust `/dev/nvme0n1` and `/dev/nvme1n1`.
It should show `/dev/disk/by-id/` candidates and require explicit selection or
preconfigured by-id paths.

## Partition Layout

### Disk 1

```text
GPT
1. /boot  4096 MiB  FAT32  GPT type EF00 / ESP flag
2. swap   16384 MiB Linux swap
3. root   remaining Btrfs member
```

### Disk 2

```text
GPT
1. swap   16384 MiB Linux swap
2. root   remaining Btrfs member
```

There is no separate `/boot/efi` partition. For Limine on CachyOS, the FAT32
boot partition is mounted directly at `/boot`.

## Btrfs Layout

Create one multi-device Btrfs filesystem across the root partitions:

```bash
mkfs.btrfs -f -d single -m raid1 <disk1-root-partition> <disk2-root-partition>
```

Target profile:

```text
Data:     single
Metadata: RAID1
System:   RAID1
```

This keeps approximately the full usable capacity of both drives while
mirroring filesystem metadata. It does not make local data authoritative; a
single disk failure can still lose file data because data blocks are not
mirrored.

## Btrfs Subvolumes

Use the CachyOS default Btrfs subvolume layout:

```text
@      -> /
@home  -> /home
@root  -> /root
@srv   -> /srv
@cache -> /var/cache
@tmp   -> /var/tmp
@log   -> /var/log
```

Do not create a custom `@games` subvolume in the baseline. Game libraries can
live under `/home` or another normal directory unless a later requirement makes
a separate subvolume worth the extra divergence.

## Mount Options

Use the CachyOS Limine installer branch defaults for Btrfs:

```text
defaults,noatime,compress=zstd,commit=120
```

Every Btrfs subvolume mount should include the appropriate `subvol=` option.

Use the CachyOS EFI/FAT mount option for `/boot`:

```text
defaults,umask=0077
```

Use periodic trim via `fstrim.timer`; do not add continuous discard mount
options.

## Swap And ZRAM

Create and enable both swap partitions:

```text
Disk 1 swap: 16 GiB
Disk 2 swap: 16 GiB
Total SSD swap: 32 GiB
```

Both swap partitions should use the same low priority, for example:

```text
pri=10
```

Keep CachyOS default ZRAM from `cachyos-settings`:

```ini
[zram0]
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
fs-type = swap
```

This means ZRAM is preferred over SSD swap. SSD swap is only the fallback once
RAM pressure exceeds what RAM and compressed ZRAM can absorb. Do not override
ZRAM to a fixed 8 GiB size in the baseline, because that is less aligned with
the supported CachyOS default.

## Bootloader Target

The target boot setup is Limine managed by CachyOS tooling:

- Install `limine` during bootstrap.
- End state should include `limine-mkinitcpio-hook`.
- Run `limine-update` after bootloader setup.
- Kernel command line should be managed through `/etc/default/limine`.

Do not use `bootctl`, `/boot/loader/loader.conf`, or systemd-boot entries.

## Package Baseline

The script should start from CachyOS's Limine Calamares `pacstrap` package
baseline, then add the selected desktop profile.

Core baseline includes:

```text
base
base-devel
btrfs-progs
cachyos-hooks
cachyos-keyring
cachyos-mirrorlist
cachyos-v3-mirrorlist
cachyos-v4-mirrorlist
cachyos-rate-mirrors
cachyos-settings
dosfstools
efibootmgr
limine
limine-mkinitcpio-hook
limine-snapper-sync
linux-cachyos
linux-cachyos-headers
linux-cachyos-lts
linux-cachyos-lts-headers
linux-firmware
mkinitcpio
sudo
chwd
plymouth
cachyos-plymouth-bootanimation
```

KDE Plasma should follow the current CachyOS netinstall package set rather than
a hand-picked minimal KDE list.

## Services

Enable at least:

```text
NetworkManager
systemd-timesyncd
fstrim.timer
bluetooth
ufw
```

The display manager should follow the chosen desktop profile. For KDE Plasma,
that means SDDM.

## Locale And Identity

Target defaults:

```text
Timezone: Europe/Amsterdam
Locale:   en_US.UTF-8
Extra:    nl_NL.UTF-8 generated
Hostname: cachyos
```

The install script should ask for the username and passwords at runtime rather
than storing secrets in the repository.

## Verification Commands

After installation, capture:

```bash
lsblk -f
findmnt /boot
findmnt /
findmnt /home
findmnt /var/cache
findmnt /var/tmp
findmnt /var/log
cat /etc/fstab
sudo btrfs filesystem show
sudo btrfs filesystem usage /
swapon --show
zramctl
cat /etc/default/limine
ls -la /boot
sudo systemctl status NetworkManager systemd-timesyncd fstrim.timer
```

## Source References

- CachyOS Desktop installation wiki:
  https://wiki.cachyos.org/installation/installation_on_root/
- CachyOS filesystem wiki:
  https://wiki.cachyos.org/installation/filesystem/
- CachyOS boot manager wiki:
  https://wiki.cachyos.org/installation/boot_managers/
- CachyOS boot manager configuration wiki:
  https://wiki.cachyos.org/configuration/boot_manager_configuration/
- CachyOS general system tweaks / ZRAM:
  https://wiki.cachyos.org/configuration/general_system_tweaks/
- CachyOS Limine Calamares mount config:
  https://raw.githubusercontent.com/CachyOS/cachyos-calamares/cachyos-limine-qt6/src/modules/mount/mount.conf
- CachyOS Limine Calamares pacstrap config:
  https://raw.githubusercontent.com/CachyOS/cachyos-calamares/cachyos-limine-qt6/src/modules/pacstrap/pacstrap.conf
- CachyOS settings ZRAM config:
  https://raw.githubusercontent.com/CachyOS/CachyOS-Settings/master/usr/lib/systemd/zram-generator.conf
- Btrfs mkfs documentation:
  https://btrfs.readthedocs.io/en/latest/mkfs.btrfs.html

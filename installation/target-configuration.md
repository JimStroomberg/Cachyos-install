# Target CachyOS Configuration

This document defines the target state for the beginner-friendly live ISO
installer.

The priority is to stay close to a supported CachyOS Desktop installation while
offering an advanced but understandable Btrfs capacity-pool layout.

Verified against upstream sources on 2026-06-11. Re-check upstream CachyOS
installer, Limine, and Secure Boot documentation before a production release.

## Installation Model

- Boot mode: UEFI only.
- Partitioning mode: guided/scripted GPT partitioning.
- Boot manager: Limine.
- Root filesystem: Btrfs on one or more selected disks.
- Desktop profile: KDE Plasma.
- Gaming profile: selectable Steam-ready AMD/Vulkan desktop bundles with
  optional Faugus Launcher and TeamSpeak 6 app installs.
- Initramfs path: CachyOS mkinitcpio/Limine tooling.
- Encryption: none.
- Secure Boot: disabled during installation.
- Hibernate: not configured.

Run the installer from the CachyOS live ISO after confirming the machine is
booted in UEFI mode.

Installer usage is documented in:

```text
installation/live-iso-installer.md
```

Secure Boot is intentionally post-install work. See:

```text
installation/post-install-secure-boot.md
```

## Firmware Preconditions

- Disable Secure Boot for the base install.
- Disable CSM/Legacy boot.
- Boot the CachyOS ISO in UEFI mode.
- Confirm EFI variables are available:

```bash
efibootmgr -v
```

If that reports EFI variables are unsupported, the ISO was not booted in UEFI
mode and installation must stop.

## Disk Selection

The installer must not blindly trust device names such as `/dev/nvme0n1`.

It should show:

- `lsblk` disk inventory
- `/dev/disk/by-id/` candidates
- disk size, model, serial, existing filesystems, labels, and mountpoints before
  final confirmation

The user selects:

1. One boot disk.
2. Zero or more additional disks for the Btrfs capacity pool.

Every selected disk is wiped.

## Partition Layout

### Boot Disk

With disk swap enabled:

```text
GPT
1. /boot  4096 MiB  FAT32  GPT type EF00 / ESP flag
2. swap   chosen size Linux swap
3. root   remaining Btrfs member
```

With no disk swap:

```text
GPT
1. /boot  4096 MiB  FAT32  GPT type EF00 / ESP flag
2. root   remaining Btrfs member
```

### Additional Pool Disks

With disk swap enabled:

```text
GPT
1. swap   chosen size Linux swap
2. root   remaining Btrfs member
```

With no disk swap:

```text
GPT
1. root   remaining Btrfs member
```

There is no separate `/boot/efi` partition. For Limine on CachyOS, the FAT32
boot partition is mounted directly at `/boot`.

## Btrfs Layout

Create one Btrfs filesystem across all selected root partitions.

Data profile:

```text
single
```

Metadata/system profile:

```text
one selected disk:       dup
two or more selected disks: raid1
```

Example one-disk command:

```bash
mkfs.btrfs -f -L cachyos -d single -m dup <root-partition>
```

Example multi-disk command:

```bash
mkfs.btrfs -f -L cachyos -d single -m raid1 <root-partition> <root-partition>...
```

This creates one large local capacity pool. It does not make local data
authoritative. Extra disks add capacity, not data redundancy. If any selected
pool disk fails, data in the filesystem may be lost because file data blocks
are not mirrored.

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

The installer offers:

- recommended disk swap
- no disk swap
- custom total disk swap

Recommended disk swap:

```text
total disk swap = installed RAM rounded up to GiB
swap per disk   = total disk swap / selected disk count
priority        = 10
```

Example:

```text
32 GiB RAM, 2 selected disks -> about 16 GiB swap per disk
32 GiB RAM, 3 selected disks -> about 10.6 GiB swap per disk
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
ZRAM to a fixed size in the baseline.

Hibernate is not configured and should not be promised by the installer.

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

The target pacman configuration must include CachyOS binary repositories, not
only Arch `core`, `extra`, and `multilib`. The installer writes the matching
optimized CachyOS repo block for v3/v4-capable CPUs plus the generic `cachyos`
repo, so installed CachyOS kernels continue to update from binary packages
instead of being rebuilt as AUR/foreign packages.

KDE Plasma core should follow the current CachyOS netinstall package set where
practical. Desktop convenience applications can be controlled by the software
selection screen.

Default-selected optional gaming bundles include:

```text
firefox
flatpak
steam
steam-devices
mesa
lib32-mesa
vulkan-radeon
lib32-vulkan-radeon
vulkan-tools
gamescope
mangohud
goverlay
wine
wine-gecko
wine-mono
winetricks
protontricks
umu-launcher
```

Optional app behavior:

```text
Faugus Launcher: selected by default, attempted from AUR as the created user
TeamSpeak 6: optional unchecked Flatpak, com.teamspeak.TeamSpeak
```

The install script must not build AUR packages as root. AUR and Flatpak app
failures are nonfatal and should produce post-install retry commands.

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

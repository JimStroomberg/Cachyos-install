

# AGENTS.md
## Tools
use Context7


## Project Overview

This project documents and validates a beginner-friendly CachyOS installer for
gaming PCs.

The original scope was a personal migration from Bazzite to CachyOS. The current
direction is broader: make the repo safe and understandable enough that the
owner can give the URL to a friend or enthusiast who can create a live USB, boot
it, open a terminal, and follow prompts.

The goal is not to create a highly available workstation or server. The primary
objective is a simple, performant, supportable CachyOS installation that follows
upstream recommendations wherever practical.

## Target Audience

Primary users:

- Beginners or enthusiasts with basic live USB knowledge.
- AMD-oriented gaming desktop users.
- Users who want one large local Btrfs storage pool.
- Users who understand, after being warned, that local storage is not a backup.

Out of scope for v1:

- Dual-boot resizing or preserving existing operating systems.
- Full-disk encryption.
- NVIDIA-specific driver tuning.
- Secure Boot during the base install.
- Hibernate configuration.

## Reference Hardware

CPU:
- AMD Ryzen 7 5800X3D

Memory:
- 32 GB RAM

GPU:
- AMD Radeon RX 6900 XT

Storage:
- 2x Samsung 980 Pro 2 TB NVMe SSD

Topology:
- NVMe1 connected directly to CPU PCIe lanes
- NVMe2 connected through chipset/southbridge

This hardware remains the main real-machine validation target, but the installer
is no longer hard-coded to exactly two disks.

## Design Decisions Already Made

### Storage

The preferred Btrfs model is a capacity pool:

```text
Data: single
Metadata/System:
  one selected disk: dup
  two or more selected disks: raid1
```

Reasoning:

- Gives users one big local volume.
- Lets every selected disk add usable capacity.
- Avoids RAID0 terminology and failure-characteristic confusion.
- Adds metadata redundancy where practical.
- Keeps the warning simple: extra disks add capacity, not data protection.

Important user-facing warning:

```text
If any disk in the Btrfs pool fails, data in the pool may be lost.
Back up important files somewhere else.
```

### Swap

The installer should offer:

```text
recommended disk swap
no disk swap
custom total disk swap
```

Default recommendation:

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

Reasoning:

- Minimal storage cost.
- Symmetrical layout.
- Useful for memory spikes.
- Hibernate is currently not a requirement.

### ZRAM

Planned configuration:

```text
CachyOS default zram from cachyos-settings
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
```

Memory hierarchy:

```text
RAM
↓
ZRAM
↓
SSD Swap
↓
OOM Killer
```

Reasoning:

- CachyOS uses ZRAM by default.
- Staying with the CachyOS default is more supportable than a custom override.
- SSD swap remains available as the lower-priority fallback.

## Bootloader

Use Limine, not systemd-boot.

Current understanding:

- CachyOS uses Limine by default.
- Current CachyOS documentation recommends a FAT32 `/boot` partition of at
  least 4 GiB.

Current preferred design:

```text
Boot disk
- /boot (FAT32, 4096 MiB, ESP/boot flag)
- optional swap
- Btrfs

Additional selected disks
- optional swap
- Btrfs
```

There is no separate `/boot/efi` partition in the target Limine layout.

## Current Implementation

Beginner entrypoint:

```text
scripts/bootstrap.sh
```

Installer:

```text
scripts/install-cachyos.sh
```

Installer modes:

```text
--preflight
--install
--install --no-tui
--self-test
--help
```

Documentation:

```text
README.md
installation/target-configuration.md
installation/live-iso-installer.md
installation/post-install-secure-boot.md
```

Key behavior:

- Bootstrap runs preflight before install.
- TUI uses `dialog` or `whiptail` when available.
- Plain Bash prompts are the fallback.
- The installer supports one or more selected disks.
- The first selected disk receives `/boot`.
- Every selected disk contributes to the Btrfs capacity pool.
- Secure Boot remains disabled during the base install.

## Important Context

The owner of this system does not consider local storage authoritative.

Important files are stored on network-backed storage that is independently
backed up.

Therefore:

- Simplicity is preferred over maximum redundancy.
- Reinstallability is preferred over complex recovery procedures.
- Following the supported CachyOS stack is preferred over custom engineering.
- Beginner-facing warnings must be direct and hard to miss.

Priority order:

1. Simple
2. Supported
3. Fast
4. Easy to reinstall
5. Redundant

## Outstanding Work

Before this documentation and installer are considered production-ready for
friends or other enthusiasts:

1. Run `scripts/install-cachyos.sh --preflight` from a real CachyOS live ISO.
2. Validate one-disk, two-disk, and three-disk destructive installs in disposable
   environments.
3. Validate the expanded gaming package baseline in a fresh install.
4. Install Faugus Launcher after first boot with `paru -S faugus-launcher`.
5. Capture post-install verification output from the real machine.
6. Keep Secure Boot as a post-install step after the base install is verified.

## Recommended Next Step

Validate the new bootstrap and preflight flow from a CachyOS live ISO:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/bootstrap.sh | bash
```

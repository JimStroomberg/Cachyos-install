

# AGENTS.md

## Project Overview

This project documents and validates a future migration from Bazzite to CachyOS on a personal gaming PC.

The goal is not to create a highly available workstation or server. The primary objective is a simple, performant, supportable CachyOS installation that follows upstream recommendations wherever practical.

## Target Hardware

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

## Design Decisions Already Made

### Storage

The preferred Btrfs configuration is:

```text
Data: single
Metadata: RAID1
System: RAID1
```

Reasoning:

- Matches the default Bazzite/Fedora implementation.
- Maximizes usable capacity (~4 TB).
- Avoids RAID0 complexity and failure characteristics.
- Provides metadata redundancy.
- Considered sufficiently reliable for a gaming PC.

### Swap

Planned layout:

```text
Disk 1
- Swap 16 GB

Disk 2
- Swap 16 GB
```

Total swap:

```text
32 GB
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

- System has 32 GB RAM.
- CachyOS uses ZRAM by default.
- Staying with the CachyOS default is more supportable than a custom 8 GB override.
- SSD swap remains available as the lower-priority fallback.

## Bootloader Investigation

Initial work assumed systemd-boot.

This assumption is now considered obsolete.

Current understanding:

- CachyOS uses Limine by default.
- Current CachyOS documentation recommends a FAT32 `/boot` partition of at least 4 GB.

Current preferred design:

```text
Disk 1
- /boot (FAT32, 4096 MiB, ESP/boot flag)
- Swap (16 GB)
- Btrfs

Disk 2
- Swap (16 GB)
- Btrfs
```

There is no separate `/boot/efi` partition in the target Limine layout.

## Finalized Target Configuration

The current target state is documented in:

```text
installation/target-configuration.md
```

Post-install Secure Boot work is tracked separately in:

```text
installation/post-install-secure-boot.md
```

The first-pass live ISO installer script is tracked in:

```text
scripts/install-cachyos.sh
installation/live-iso-installer.md
```

Key updates from the earlier draft:

- Use Limine, not systemd-boot.
- Mount the FAT32 boot partition directly at `/boot`.
- Use CachyOS's default Btrfs subvolumes: `@`, `@home`, `@root`, `@srv`, `@cache`, `@tmp`, `@log`.
- Do not create a custom `@games` subvolume in the baseline.
- Use CachyOS-style Btrfs mount options: `defaults,noatime,compress=zstd,commit=120`.
- Keep CachyOS's default ZRAM behavior from `cachyos-settings`.
- Keep Secure Boot disabled during the base install; enable it only as a separate post-install step.

## Outstanding Work

Before this documentation is considered production-ready:

1. Validate `scripts/install-cachyos.sh` in a VM or disposable test environment where possible.
2. Validate the final process on real hardware.
3. Capture post-install verification output from the real machine.
4. Configure Secure Boot only after the base install is verified.
5. Replace the placeholder GitHub raw URL in `installation/live-iso-installer.md` once the repository location is known.

## Important Context

The owner of this system does not consider local storage authoritative.

Important files are stored on network-backed storage that is independently backed up.

Therefore:

- Simplicity is preferred over maximum redundancy.
- Reinstallability is preferred over complex recovery procedures.
- Following the supported CachyOS stack is preferred over custom engineering.

Priority order:

1. Simple
2. Supported
3. Fast
4. Easy to reinstall
5. Redundant

## Recommended Next Step

Validate `scripts/install-cachyos.sh` from a CachyOS live ISO or a close
disposable test environment before using it on the real machine.

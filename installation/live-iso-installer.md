# Live ISO Installer

The live ISO installer is:

```text
scripts/install-cachyos.sh
```

The beginner entrypoint is:

```text
scripts/bootstrap.sh
```

Run both from a CachyOS live ISO booted in UEFI mode.

## Recommended Beginner Flow

From the live environment:

1. Connect to the internet.
2. Open a terminal.
3. Run the bootstrap command.
4. Review the preflight report.
5. Continue into the guided installer only if the report looks reasonable.

Command:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/bootstrap.sh | bash
```

The bootstrap script downloads the repository with `git` when possible. If
`git` is unavailable or cloning fails, it downloads the installer script
directly with `curl`.

## Installer Modes

Non-destructive preflight:

```bash
sudo bash scripts/install-cachyos.sh --preflight
```

Guided destructive install:

```bash
sudo bash scripts/install-cachyos.sh --install
```

Guided install with plain prompts instead of `dialog` or `whiptail`:

```bash
sudo bash scripts/install-cachyos.sh --install --no-tui
```

By default, `--install` uses `dialog` or `whiptail` for terminal menus. If both
are missing, the installer tries to install `dialog` into the temporary live
environment with pacman. If that fails, it falls back to numbered prompts.

Show help:

```bash
bash scripts/install-cachyos.sh --help
```

Run calculation checks:

```bash
bash scripts/install-cachyos.sh --self-test
```

## Preflight Report

The preflight mode checks:

- root status
- interactive terminal availability
- operating system identity
- UEFI boot state
- EFI variable access
- Secure Boot state
- RAM size
- GPU inventory
- network reachability
- pacman configuration
- available TUI tool
- required installer commands
- disk inventory
- stable disk identifiers

Preflight is informational. The destructive installer still performs hard-stop
checks before making changes.

## Guided Disk Model

The installer now supports one or more selected disks:

- The first selected disk is the boot disk.
- The boot disk gets a 4096 MiB FAT32 `/boot` partition.
- All selected disks contribute one Btrfs member partition.
- Optional swap partitions can be spread across all selected disks.
- Btrfs data is always `single`.
- Btrfs metadata/system is `dup` on one disk and `raid1` on two or more disks.

This is a capacity pool, not a redundant data pool. More disks mean more local
storage, but one failed pool disk can still cause data loss.

## Swap Choices

The installer offers:

- recommended swap
- no disk swap
- custom total disk swap

Recommended swap equals installed RAM rounded up to GiB, split evenly across
the selected disks. Disk swap uses low priority. CachyOS ZRAM remains the
preferred swap layer.

Hibernate is not configured.

## What The Script Installs

- CachyOS base packages and Limine tooling
- KDE Plasma desktop packages
- Firefox
- Flatpak and Flathub
- Steam and Steam device rules
- AMD Mesa/Vulkan packages, including 32-bit Vulkan support
- Gamescope
- MangoHud and GOverlay
- Wine, Wine Mono, Wine Gecko, Winetricks, Protontricks
- UMU Launcher
- Faugus Launcher dependencies
- `paru` for AUR packages

Faugus Launcher itself remains a post-install AUR step:

```bash
paru -S faugus-launcher
```

## Logging

Each run writes a full log to the live environment Desktop when possible:

```text
~/Desktop/cachyos-install-YYYYmmdd-HHMMSS.log
```

If no live user Desktop can be found, the script falls back to `/tmp`.

## Current Status

The original fixed two-disk installer completed successfully on target
hardware. The beginner-friendly multi-disk refactor still needs validation from
a real CachyOS live ISO and disposable destructive test environments.

Secure Boot is intentionally not configured by this script. See:

```text
installation/post-install-secure-boot.md
```

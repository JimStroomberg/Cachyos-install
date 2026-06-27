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

By default, `--install` prefers `dialog` for terminal menus. If `dialog` is
missing, the installer tries to install it into the temporary live environment
with pacman. If that fails, it falls back to `whiptail` or numbered prompts.

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

If the live ISO pacman config is missing CachyOS repository sections, preflight
warns about it. The install step still normalizes the target `/etc/pacman.conf`
and enables the appropriate CachyOS binary repos for the detected CPU level:
AMD Zen 4/5 `znver4`, otherwise x86-64-v4, x86-64-v3, or generic `cachyos`.

## Guided Disk Model

The installer now supports one or more selected disks:

- The first selected disk is the boot disk.
- The boot disk gets a 4096 MiB FAT32 `/boot` partition.
- All selected disks contribute one Btrfs member partition.
- USB disks are excluded from the target list to avoid wiping installer or
  backup media.
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

## Software Selection

The installer always installs the fixed CachyOS/KDE base: core system packages,
kernels, firmware, Btrfs tools, Limine tooling, NetworkManager, CachyOS
settings, KDE Plasma core, and required support packages.

It then shows grouped optional software choices. Defaults match the current
gaming-ready install:

- Firefox browser
- Steam, Steam device rules, AMD Vulkan, and 32-bit Vulkan support
- Wine, Wine Mono, Wine Gecko, Winetricks, Protontricks, and UMU Launcher
- Gamescope, MangoHud, and GOverlay
- desktop tools, media apps, editors, and terminal utilities
- maintenance tools such as Git, SSH, rsync, smartmontools, `paru`, and package helpers
- Flatpak support and Flathub
- Faugus Launcher AUR install attempt

TeamSpeak 6 is available as an unchecked optional Flatpak app:

```text
com.teamspeak.TeamSpeak
```

Selecting TeamSpeak automatically enables Flatpak support. Flatpak and AUR app
installation failures are nonfatal; the installer logs the failure and prints a
post-install retry command.

The installed desktop also gets an "Update Machine" helper:

- `/usr/local/bin/update-machine`
- application menu entry: `Update Machine`
- Desktop launcher: `~/Desktop/Update Machine.desktop`

The helper opens in Konsole and offers recommended official repo plus firmware
updates, repo-only updates, firmware-only updates, and optional AUR/foreign
updates. Logs are written to `~/.local/state/update-machine/`.

## Logging

Each run writes a full log to the live environment Desktop when possible:

```text
~/Desktop/cachyos-install-YYYYmmdd-HHMMSS.log
```

If no live user Desktop can be found, the script falls back to `/tmp`.

After a successful install or real failure stop, the installer asks whether to
upload the log to Jim's JLogger service. The default answer is yes, but upload
only happens after that dedicated prompt.

Uploaded logs may include hardware details, disk layout, package output,
bootloader output, usernames, hostnames, device identifiers, and similar
installation context. JLogger redacts obvious secrets before storage and keeps
logs for about 14 days.

When upload succeeds, the installer prints a Debug ID. Share that ID when
asking Jim for help. The installer does not print retrieval URLs, admin tokens,
or cloud credentials.

## Current Status

The original fixed two-disk installer completed successfully on target
hardware. The beginner-friendly multi-disk refactor still needs validation from
a real CachyOS live ISO and disposable destructive test environments.

Secure Boot is intentionally not configured by this script. See:

```text
installation/post-install-secure-boot.md
```

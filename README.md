# CachyOS Gaming PC Installer

This repository provides a guided CachyOS installer for beginner-to-intermediate
users who want a gaming-ready KDE desktop with a larger Btrfs storage pool than
the standard GUI installer usually exposes.

The target audience is someone who can create a CachyOS live USB, boot it in
UEFI mode, open a terminal, and follow prompts carefully.

## Read This First

This is a destructive fresh-install tool.

- It wipes every disk you select.
- It does not preserve Windows, Linux, recovery partitions, or game libraries.
- Extra disks add storage capacity, not data redundancy.
- If any disk in the Btrfs pool dies, data in the pool may be lost.
- Important files must already be backed up somewhere else.

The installer is designed for AMD-oriented gaming desktops and keeps close to
CachyOS defaults where practical:

- Boot mode: UEFI
- Bootloader: Limine
- Desktop: KDE Plasma
- Filesystem: Btrfs
- Boot partition: FAT32 `/boot`, 4096 MiB, on the first selected disk
- Btrfs data profile: `single`
- Btrfs metadata/system profile: `dup` on one disk, `raid1` on two or more disks
- ZRAM: CachyOS default behavior from `cachyos-settings`
- Gaming baseline: Steam, AMD Vulkan, 32-bit Vulkan, Wine tooling, Gamescope,
  MangoHud, Flatpak, Firefox, UMU Launcher, and Faugus Launcher dependencies

## Quick Start

Boot the CachyOS live USB in UEFI mode, connect to the internet, open a
terminal, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/bootstrap.sh | bash
```

The bootstrap script:

1. Shows the project URL.
2. Downloads or locates the installer.
3. Runs a non-destructive preflight report.
4. Waits for you to review the report.
5. Starts the guided destructive installer.

The installer writes a timestamped log to the live environment Desktop when
possible:

```text
~/Desktop/cachyos-install-YYYYmmdd-HHMMSS.log
```

If no Desktop folder is available, logs go to `/tmp`.

The guided installer prefers `dialog` for terminal menus. If `dialog` is not
available, it tries to install the small `dialog` package into the temporary
live environment before falling back to `whiptail` or numbered prompts.

## What The Installer Asks

- Which disk should contain `/boot`.
- Which additional disks should join the Btrfs capacity pool.
- Whether to create disk swap partitions.
- Hostname.
- Primary username.
- Timezone.
- Root password.
- User password.
- Final destructive confirmation.

The default disk swap recommendation is total swap equal to installed RAM,
split evenly across the selected disks. For example, a 32 GiB RAM system with
two selected disks gets about 16 GiB swap per disk. CachyOS ZRAM remains the
preferred swap layer; disk swap is only the lower-priority fallback.

## Before You Wipe Anything

Check these before continuing past the final confirmation:

- You booted the USB in UEFI mode.
- Secure Boot is disabled for the base install.
- The disks shown in the summary are the disks you intend to erase.
- Anything important is backed up outside this machine.
- You understand that the Btrfs pool is capacity-focused, not redundant.
- You saved or can access the installer log if debugging is needed.

## What This Does Not Do

The v1 installer warns but does not implement:

- Dual-boot resizing or preserving existing operating systems.
- Full-disk encryption.
- NVIDIA-specific driver tuning.
- Secure Boot setup during the base install.
- Hibernate configuration.
- Local data backup.

Secure Boot is intentionally handled after the installed system has booted
successfully. See
[installation/post-install-secure-boot.md](installation/post-install-secure-boot.md).

## Manual Commands

Run only the preflight report:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/install-cachyos.sh | sudo bash -s -- --preflight
```

Run the guided installer directly:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/install-cachyos.sh | sudo bash -s -- --install
```

Force plain prompts instead of `dialog` or `whiptail`:

```bash
sudo bash scripts/install-cachyos.sh --install --no-tui
```

## Documentation

- [Live ISO installer usage](installation/live-iso-installer.md)
- [Target configuration](installation/target-configuration.md)
- [Post-install Secure Boot](installation/post-install-secure-boot.md)
- [Agent/project context](AGENTS.md)

## Safety Status

Current status: installer-product refactor in progress.

Verified in this repo:

- Bash syntax validation.
- Installer calculation self-test.
- Beginner-facing preflight/install modes.
- Bootstrap entrypoint.
- GitHub Actions static-check workflow.

Still required before recommending this to other people:

- Run `--preflight` from a real CachyOS live ISO.
- Run a disposable VM or loop-device install matrix for one, two, and three
  selected disks.
- Perform a fresh hardware install with the expanded beginner flow.
- Capture sanitized verification output from the real machine.

## Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── static-checks.yml
├── AGENTS.md
├── README.md
├── installation/
│   ├── live-iso-installer.md
│   ├── post-install-secure-boot.md
│   └── target-configuration.md
└── scripts/
    ├── bootstrap.sh
    └── install-cachyos.sh
```

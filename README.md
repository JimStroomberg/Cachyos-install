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
- Software: grouped selector with today’s gaming-ready defaults selected

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

At the end of an install or real failure stop, the installer asks whether to
upload the log to Jim's JLogger service. The default answer is yes, but the
prompt is explicit. Uploaded logs may include hardware details, disk layout,
package output, bootloader output, usernames, hostnames, device identifiers,
and similar installation context. JLogger redacts obvious secrets before
storage and keeps logs for about 14 days. When an upload succeeds, the
installer prints a Debug ID to share when asking for help.

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
- Optional software bundles.
- Final destructive confirmation.
- Optional log upload after success or a real failure stop.

Password input is hidden. The installer tells users that no characters or
asterisks will be shown while typing, but the keystrokes are still recorded.

The default disk swap recommendation is total swap equal to installed RAM,
split evenly across the selected disks. For example, a 32 GiB RAM system with
two selected disks gets about 16 GiB swap per disk. CachyOS ZRAM remains the
preferred swap layer; disk swap is only the lower-priority fallback.

Default-selected software bundles match the current gaming-ready install:
Firefox, Steam/AMD Vulkan, Wine tooling, Gamescope/MangoHud, desktop tools,
maintenance tools, Flatpak support, and a nonfatal Faugus Launcher AUR install
attempt. TeamSpeak 6 is available as an unchecked optional Flatpak selection.
Optional Flatpak and AUR app failures are logged but do not fail the base OS
install.

Fresh installs also get an "Update Machine" helper in the application menu and
on the user's Desktop. It opens a terminal menu for official repo updates,
firmware updates, and optional AUR/foreign package updates. Its logs are stored
under:

```text
~/.local/state/update-machine/
```

After pacstrap, the installer normalizes the target `/etc/pacman.conf` so the
CachyOS binary repositories are enabled. On v3/v4-capable CPUs this includes
the matching optimized CachyOS repos before the Arch repos, preventing CachyOS
kernels and base packages from being treated as AUR/foreign packages later.

## Before You Wipe Anything

Check these before continuing past the final confirmation:

- You booted the USB in UEFI mode.
- Secure Boot is disabled for the base install.
- The disks shown in the summary are the disks you intend to erase.
- USB disks are hidden from the target picker to avoid wiping the installer or
  backup media.
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

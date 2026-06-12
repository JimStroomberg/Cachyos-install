# Live ISO Installer Script

The install script is:

```text
scripts/install-cachyos.sh
```

It is intended to be run from a CachyOS live ISO booted in UEFI mode.

## GitHub Command

From the CachyOS live ISO, the flow should be:

1. Open a browser in the live environment.
2. Navigate to the repository.
3. Copy the raw install command.
4. Paste it into a terminal.

Command:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/install-cachyos.sh | sudo bash
```

## What The Script Does

- Verifies the ISO is booted in UEFI mode.
- Lists disks and `/dev/disk/by-id/` candidates.
- Suggests likely Samsung 980 Pro NVMe targets.
- Prompts for the two target disks.
- Requires the exact destructive confirmation phrase `WIPE AND INSTALL`.
- Wipes and repartitions both selected disks.
- Creates the target `/boot`, swap, and multi-device Btrfs layout.
- Creates CachyOS default Btrfs subvolumes.
- Installs the CachyOS package baseline, KDE Plasma, Firefox, Steam, AMD
  Vulkan support, Wine tooling, Gamescope, MangoHud, and Faugus Launcher
  dependencies.
- Copies the CachyOS live ISO pacman repository configuration into the target
  system and ensures `multilib` is enabled.
- Adds the Flathub Flatpak remote.
- Configures timezone, locales, hostname, user, sudo, services, and Limine.
- Saves full output to a timestamped log on the live environment Desktop.
- Prints verification output before reboot.

## User Inputs

The script asks for:

- Disk 1.
- Disk 2.
- Hostname.
- Primary username.
- Root password.
- User password.
- Destructive confirmation.

## Current Status

The base installer has completed successfully on the target hardware. The
expanded gaming package baseline still needs a fresh full-run validation.

Secure Boot is intentionally not configured by this script. See:

```text
installation/post-install-secure-boot.md
```

## Logging

Each run writes a full log to the live environment Desktop:

```text
~/Desktop/cachyos-install-YYYYmmdd-HHMMSS.log
```

If no live user Desktop can be found, the script falls back to `/tmp`.

## Faugus Launcher

The script installs the dependencies and AUR tooling needed for Faugus Launcher,
but it does not automatically build AUR packages during installation.

After first boot:

```bash
paru -S faugus-launcher
```

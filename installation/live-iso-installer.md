# Live ISO Installer Script

The install script is:

```text
scripts/install-cachyos.sh
```

It is intended to be run from a CachyOS live ISO booted in UEFI mode.

## Future GitHub Command

After this repository is pushed to GitHub, the live ISO flow should be:

1. Open a browser in the live environment.
2. Navigate to the repository.
3. Copy the raw install command.
4. Paste it into a terminal.

Command shape:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/scripts/install-cachyos.sh | sudo bash
```

Replace `<owner>`, `<repo>`, and `<branch>` with the real GitHub location.

## What The Script Does

- Verifies the ISO is booted in UEFI mode.
- Lists disks and `/dev/disk/by-id/` candidates.
- Suggests likely Samsung 980 Pro NVMe targets.
- Prompts for the two target disks.
- Requires the exact destructive confirmation phrase `WIPE AND INSTALL`.
- Wipes and repartitions both selected disks.
- Creates the target `/boot`, swap, and multi-device Btrfs layout.
- Creates CachyOS default Btrfs subvolumes.
- Installs the CachyOS package baseline and KDE Plasma.
- Configures timezone, locales, hostname, user, sudo, services, and Limine.
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

This is a first-pass automation script. It has Bash syntax checks only until it
is run from an actual CachyOS live ISO or a close disposable test environment.

Secure Boot is intentionally not configured by this script. See:

```text
installation/post-install-secure-boot.md
```

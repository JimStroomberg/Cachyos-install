# Post-Install Secure Boot

This document is intentionally separate from the base installation target.

The base install should be completed and verified first with Secure Boot
disabled. Secure Boot can then be enabled as a post-install hardening step.

Verified against upstream sources on 2026-06-11.

## Scope

Target system:

- CachyOS Desktop.
- UEFI boot.
- Limine boot manager.
- FAT32 `/boot`.
- No separate `/boot/efi`.
- No full-disk encryption.

This document is not part of the first-pass live-ISO install script. It should
be implemented as a separate post-install script or runbook after the machine
boots successfully.

## Why Separate

CachyOS explicitly requires Secure Boot to be disabled during installation.
The installation should prove that partitioning, Btrfs, Limine, kernel entries,
users, networking, and services all work before adding firmware key management
and boot-chain signing.

Keeping this separate also avoids mixing destructive disk work with firmware
state changes.

## Important Limine Notes

Do not use `sbctl-batch-sign` for the Limine baseline.

CachyOS documents `sbctl-batch-sign` as not compatible with Limine. Limine can
hash-check its boot files; manually signing kernel/initramfs files can modify
files after Limine has calculated hashes and cause checksum verification
failures.

For Limine, the CachyOS Secure Boot path is:

- Use `sbctl` for custom Secure Boot keys.
- Enable Limine config checksum enrollment.
- Use `limine-enroll-config`.
- Run `limine-update`.
- Sign only what Limine needs through the Limine tooling path.

## Preconditions

Before starting:

```bash
findmnt /boot
cat /etc/default/limine
ls -la /boot
sudo limine-update
sudo sbctl status
```

Expected before Secure Boot setup:

```text
Setup Mode: may be enabled only after firmware key reset
Secure Boot: Disabled
```

Install `sbctl` if it is missing:

```bash
sudo pacman -S sbctl
```

## Firmware Setup Mode

Reboot into firmware:

```bash
systemctl reboot --firmware-setup
```

In firmware:

- Put Secure Boot into setup/custom mode.
- Clear or delete existing Secure Boot variables if needed.
- Keep CSM disabled.
- Do not enable Secure Boot enforcement yet unless the key enrollment steps
  have already succeeded.

Motherboard notes:

- MSI boards may require Secure Boot Mode `Custom` plus a maximum-security
  compatibility option.
- Some ASUS boards require deleting Secure Boot variables under key management.
- Some ASUS boards enable Secure Boot by setting OS Type to `Windows UEFI Mode`;
  `Other OS` can mean Secure Boot is effectively disabled.

## Enroll Keys With sbctl

After rebooting back into CachyOS with firmware in setup mode:

```bash
sudo sbctl status
sudo sbctl create-keys
```

Default enrollment:

```bash
sudo sbctl enroll-keys --microsoft --firmware-builtin
```

ASUS exception:

```bash
sudo sbctl enroll-keys --microsoft
```

Use the ASUS exception if the board creates duplicate `builtin-db` entries or
throws a Secure Boot violation after enrollment.

Check status:

```bash
sudo sbctl status
```

At this point, Secure Boot can still show disabled. That is expected until the
firmware Secure Boot enforcement option is enabled.

## Configure Limine For Secure Boot

Enable Limine config checksum enrollment:

```bash
sudoedit /etc/default/limine
```

Ensure this setting exists:

```text
ENABLE_ENROLL_LIMINE_CONFIG=yes
```

Check `/boot/limine.conf` for a wallpaper line:

```bash
sudo cat /boot/limine.conf
```

If the config contains a line like:

```text
wallpaper: boot():/limine-splash.png
```

generate a BLAKE2B hash:

```bash
sudo b2sum /boot/limine-splash.png
```

Append the generated hash to the wallpaper path in `/boot/limine.conf`:

```text
wallpaper: boot():/limine-splash.png#<generated-hash>
```

Then enroll and update Limine:

```bash
sudo limine-enroll-config
sudo limine-update
```

## Enable Secure Boot In Firmware

Reboot into firmware again:

```bash
systemctl reboot --firmware-setup
```

Enable Secure Boot enforcement.

For ASUS boards that use the `OS Type` wording, use:

```text
Boot -> Secure Boot
OS Type          -> Windows UEFI Mode
Secure Boot Mode -> Custom
```

Boot back into CachyOS.

## Verification

Run:

```bash
sudo sbctl status
bootctl
sudo limine-update
sudo sbctl verify
```

Expected:

```text
Secure Boot: Enabled
Setup Mode: Disabled
```

If `sbctl verify` reports unsigned kernel/initramfs paths under `/boot`, do not
blindly run `sbctl-batch-sign` on this Limine setup. Re-check Limine Secure Boot
configuration first.

## Recovery Notes

If the machine fails to boot after enabling Secure Boot:

1. Disable Secure Boot in firmware.
2. Boot the installed system again, or boot the CachyOS live ISO.
3. Use `cachy-chroot` if needed.
4. Re-check `/etc/default/limine`, `/boot/limine.conf`, `limine-enroll-config`,
   and `limine-update`.

## Source References

- CachyOS installation guide, Secure Boot disabled during install:
  https://wiki.cachyos.org/installation/installation_on_root/
- CachyOS Secure Boot setup:
  https://wiki.cachyos.org/configuration/secure_boot_setup/
- CachyOS Settings, `sbctl-batch-sign` Limine incompatibility:
  https://wiki.cachyos.org/features/cachyos_settings/

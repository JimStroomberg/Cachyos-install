# Post-Install Secure Boot

This runbook enables Secure Boot after the CachyOS base install has already
booted successfully from the internal NVMe.

Do not run this during the live ISO installation. Do not enable Secure Boot in
firmware until the Limine enrollment step below has completed.

Verified against upstream sources on 2026-06-11.

## Target

- CachyOS Desktop
- UEFI boot
- Limine boot manager
- FAT32 `/boot`
- No separate `/boot/efi`
- No full-disk encryption

## Important Limine Rule

Do not use `sbctl-batch-sign` on this Limine setup.

CachyOS documents `sbctl-batch-sign` as incompatible with Limine. Limine can
verify boot file hashes, and generic signing can modify files after Limine has
calculated checksums.

Use this flow instead:

```text
sbctl keys -> firmware key enrollment -> Limine config enrollment -> limine-update -> enable Secure Boot
```

## 1. Confirm Base System

Run this from the installed CachyOS system, not from the live ISO:

```bash
findmnt /
findmnt /boot
sudo btrfs filesystem usage /
swapon --show
sudo limine-update
```

If those commands look sane and `limine-update` succeeds, continue.

## 2. Install sbctl

```bash
sudo pacman -Syu sbctl
sudo sbctl status
```

Before firmware setup, it is normal to see:

```text
Secure Boot: Disabled
Setup Mode: Disabled
```

That means the firmware still has existing keys enrolled. Continue to the next
step.

## 3. Enter Firmware Setup Mode

Reboot into firmware:

```bash
systemctl reboot --firmware-setup
```

In firmware:

- Keep Secure Boot enforcement disabled for now.
- Set Secure Boot mode to `Custom` if available.
- Clear/delete existing Secure Boot keys, or choose the firmware option that
  resets Secure Boot to setup mode.
- Keep CSM/Legacy boot disabled.
- Save and reboot back into CachyOS.

Back in CachyOS, confirm setup mode:

```bash
sudo sbctl status
```

Expected:

```text
Secure Boot: Disabled
Setup Mode: Enabled
```

Do not enable Secure Boot yet.

## 4. Create And Enroll Keys

Run:

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl status
```

After enrollment, it is normal for setup mode to become disabled again while
Secure Boot itself still remains disabled:

```text
Secure Boot: Disabled
Setup Mode: Disabled
```

If enrollment fails on an ASUS board or the firmware reports duplicate
`builtin-db` entries, use this enrollment command instead:

```bash
sudo sbctl enroll-keys --microsoft
```

Do not reboot to enable Secure Boot yet. Configure Limine first.

## 5. Configure Limine Enrollment

Enable Limine config enrollment:

```bash
sudo sed -i 's/^ENABLE_ENROLL_LIMINE_CONFIG=.*/ENABLE_ENROLL_LIMINE_CONFIG=yes/' /etc/default/limine
grep -q '^ENABLE_ENROLL_LIMINE_CONFIG=' /etc/default/limine || echo 'ENABLE_ENROLL_LIMINE_CONFIG=yes' | sudo tee -a /etc/default/limine
```

Enroll and update Limine:

```bash
sudo limine-enroll-config
sudo limine-update
sudo sbctl status
```

If both Limine commands succeed, continue.

## 6. Enable Secure Boot In Firmware

Reboot into firmware:

```bash
systemctl reboot --firmware-setup
```

In firmware:

- Enable Secure Boot enforcement.
- Keep Secure Boot mode as `Custom` if that is how keys were enrolled.
- Save and boot back into CachyOS.

ASUS wording may look like this:

```text
Boot -> Secure Boot
OS Type          -> Windows UEFI Mode
Secure Boot Mode -> Custom
```

On some ASUS boards, `Other OS` means Secure Boot is effectively disabled.

## 7. Verify After Boot

Back in CachyOS:

```bash
sudo sbctl status
sudo sbctl verify
sudo limine-update
```

Expected:

```text
Secure Boot: Enabled
Setup Mode: Disabled
```

If `sbctl verify` reports unsigned kernel or initramfs files under `/boot`, do
not run `sbctl-batch-sign`. Re-check `/etc/default/limine`, run
`limine-enroll-config`, then run `limine-update` again.

## Troubleshooting

### Red Screen: Invalid Signature Detected

Symptom during boot:

```text
Invalid signature detected. Check Secure Boot Policy in Setup.
```

If CachyOS still boots after acknowledging the warning, or if changing firmware
boot order fixes it, the likely cause is firmware trying an unsigned fallback
EFI entry before the signed Limine entry.

Check boot entries:

```bash
sudo efibootmgr -v
sudo sbctl verify
```

The signed entry should point at Limine:

```text
\EFI\limine\limine_x64.efi
```

The fallback entry may point at:

```text
\EFI\BOOT\BOOTX64.EFI
```

If `sbctl verify` shows `limine_x64.efi` as signed but `BOOTX64.EFI` as
unsigned, put the signed Limine entry first in firmware boot order.

You can do this directly in firmware setup, or with `efibootmgr`. Example only:

```bash
sudo efibootmgr -v
sudo efibootmgr -o 0001,0004
```

Replace `0001` and `0004` with the actual boot numbers from your machine.

After confirming the signed Limine entry boots correctly with Secure Boot
enabled, the unsigned fallback entry can optionally be removed. Example only:

```bash
sudo efibootmgr -b 0004 -B
```

Do not remove the working signed Limine entry.

## Recovery

If the machine fails to boot after enabling Secure Boot:

1. Disable Secure Boot in firmware.
2. Boot the installed system again, or boot the CachyOS live ISO.
3. Use `cachy-chroot` if needed.
4. Re-check:

```bash
cat /etc/default/limine
sudo limine-enroll-config
sudo limine-update
sudo sbctl status
```

## Source References

- CachyOS installation guide, Secure Boot disabled during install:
  https://wiki.cachyos.org/installation/installation_on_root/
- CachyOS Secure Boot setup:
  https://wiki.cachyos.org/configuration/secure_boot_setup/
- CachyOS Settings, `sbctl-batch-sign` Limine incompatibility:
  https://wiki.cachyos.org/features/cachyos_settings/

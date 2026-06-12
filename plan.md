# Disk Encryption Experiment Plan

This branch explores making disk encryption a standard option for the CachyOS
installer while preserving the beginner-friendly storage model from `main`.

## Goal

Encrypted installs should normally boot without asking the user for a disk
password:

```text
Power on PC
Limine boots CachyOS
TPM unlocks LUKS automatically
User reaches KDE login screen
```

Manual unlock is still required when the trusted boot state changes, for
example:

```text
Secure Boot disabled
boot chain changed
booting from a live USB
TPM enrollment no longer matches
```

In those cases the user unlocks with a recovery key.

## Target Design

- Keep `/boot` unencrypted, FAT32, 4096 MiB, on the boot disk.
- Encrypt the Btrfs root pool with LUKS2.
- Keep the Btrfs model:
  - data: `single`
  - metadata/system: `dup` for one disk, `raid1` for two or more disks
- Use TPM2 auto-unlock as the standard encrypted boot path.
- Generate one recovery key during installation.
- Add the recovery key to every encrypted root container.
- Save the recovery key to a writable removable USB drive when available.
- If no writable USB drive is available, display the key and require explicit
  confirmation that the user saved it.
- Disable disk swap for the first encryption experiment; keep CachyOS ZRAM.
- Keep Secure Boot setup as a separate post-install step.

## Important TPM/Secure Boot Constraint

TPM enrollment must match the final boot state.

If TPM unlock is enrolled while Secure Boot is disabled, and Secure Boot is
enabled later, the PCR state changes. TPM auto-unlock may fail until the TPM
slot is re-enrolled.

Therefore the implementation should use a staged flow:

1. During install:
   - create LUKS2 containers
   - generate and enroll the recovery key
   - optionally enroll temporary TPM unlock for first boot while Secure Boot is
     still disabled
2. After first boot:
   - user completes Secure Boot setup
   - user may need the recovery key once after the Secure Boot state changes
   - user runs a finalization helper to re-enroll TPM against the final trusted
     boot state

## Proposed User Flow

During the installer:

1. User selects encrypted install.
2. Installer explains:
   - TPM normally unlocks automatically.
   - Recovery key is required if Secure Boot is disabled or the boot chain
     changes.
   - Whoever has the recovery key can unlock the disks.
3. Installer disables disk swap for this experimental mode.
4. Installer creates LUKS2 root containers.
5. Installer generates one recovery key.
6. Installer adds the recovery key to every encrypted root container.
7. Installer saves the recovery key to a writable removable USB drive if one is
   available.
8. Installer requires typed confirmation:

```text
I HAVE SAVED THE RECOVERY KEY
```

After first boot:

1. User verifies the encrypted install boots.
2. User follows the Secure Boot runbook.
3. User runs a helper, for example:

```bash
sudo cachyos-finalize-tpm-unlock
```

The helper should:

- verify Secure Boot is enabled
- verify encrypted root containers exist
- verify recovery-key access exists
- remove stale TPM slots if needed
- enroll TPM2 unlock against the current Secure Boot-enabled PCR state
- print verification output

## Installer Implementation Notes

Add an encryption choice:

```text
No encryption
Experimental LUKS2 + TPM unlock
```

Default should remain `No encryption` until this branch is validated.

For encrypted mode:

- Root partitions become LUKS backing partitions.
- Mapper names should be deterministic:

```text
cachyos-root0
cachyos-root1
cachyos-root2
```

- Btrfs should be created on mapper devices:

```bash
mkfs.btrfs -f -L cachyos -d single -m <dup|raid1> /dev/mapper/cachyos-root0 ...
```

- Limine kernel command line should include one mapping per encrypted root
  partition:

```text
rd.luks.name=<luks_uuid_0>=cachyos-root0
rd.luks.name=<luks_uuid_1>=cachyos-root1
```

- TPM options should be added only when TPM enrollment is active:

```text
rd.luks.options=<luks_uuid>=tpm2-device=auto
```

- Initramfs should use the systemd encryption path:

```text
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

Keep `cryptsetup` and `device-mapper` in the package baseline.

## Recovery Key Handling

The installer should look for writable removable storage and avoid silently
writing secrets to internal disks.

Preferred recovery key filename:

```text
CACHYOS-RECOVERY-KEY-<hostname>-<date>.txt
```

The recovery key file should explain:

- what machine/install it belongs to
- that it unlocks the encrypted disks
- that it must be stored separately
- that it is needed if TPM unlock fails

The live installer USB may be read-only depending on how it was created, so the
installer must handle the no-writable-USB case cleanly.

## Verification Commands

During install verification:

```bash
lsblk -f
cryptsetup status cachyos-root0
cat /etc/mkinitcpio.conf
cat /etc/default/limine
btrfs filesystem show
btrfs filesystem usage /mnt
```

After boot:

```bash
lsblk -f
findmnt /
findmnt /boot
systemd-cryptenroll --list-devices
sudo cryptsetup luksDump <root-partition>
cat /etc/default/limine
sudo btrfs filesystem show
```

## Test Matrix

Start in UTM or another disposable environment:

```text
1 disk, encrypted root, no disk swap
2 disks, encrypted root pool, no disk swap
3 disks, encrypted root pool, no disk swap
```

Acceptance criteria:

- installer completes
- recovery key is generated and confirmed
- system boots encrypted root
- TPM auto-unlock works in the expected boot state
- recovery key unlock works when TPM unlock is unavailable
- all selected encrypted devices appear in `btrfs filesystem show`
- `limine-update` does not break boot
- reboot works twice

## Later Work

After root encryption is proven:

- Add encrypted disk swap.
- Decide whether TPM-only unlock should remain standard or whether a
  passphrase fallback prompt should also be enrolled.
- Add stronger Secure Boot integration checks.
- Document TPM breakage and recovery scenarios for firmware updates, Secure
  Boot changes, and bootloader/initramfs changes.

# CachyOS Gaming PC Install

This repository documents and automates a fresh CachyOS installation for a
personal gaming PC currently planned as a migration from Bazzite.

The goal is a simple, performant, supportable install that stays close to the
current CachyOS Desktop defaults while using a two-NVMe multi-device Btrfs
layout.

## Target System

- CPU: AMD Ryzen 7 5800X3D
- Memory: 32 GB RAM
- GPU: AMD Radeon RX 6900 XT
- Storage: 2x Samsung 980 Pro 2 TB NVMe SSDs
- Desktop: KDE Plasma
- Boot mode: UEFI
- Bootloader: Limine
- Filesystem: Btrfs across both NVMe SSDs

## Target Layout

Disk 1:

```text
/boot  FAT32  4096 MiB
swap   16 GiB
Btrfs  remaining space
```

Disk 2:

```text
swap   16 GiB
Btrfs  remaining space
```

Btrfs profile:

```text
Data:     single
Metadata: RAID1
System:   RAID1
```

This maximizes local usable capacity while mirroring Btrfs metadata. Local
storage is not treated as authoritative; important data is expected to live on
separately backed-up network storage.

## Installer Script

The live ISO installer is:

```text
scripts/install-cachyos.sh
```

It is a destructive fresh-install script intended to run from a CachyOS live ISO
booted in UEFI mode.

From the CachyOS live ISO, run:

```bash
curl -fsSL https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main/scripts/install-cachyos.sh | sudo bash
```

The script prompts for the target disks, hostname, username, passwords, and a
destructive confirmation phrase before wiping anything.

## Safety Status

Current status: first-pass automation.

Verified so far:

- The target configuration has been checked against current CachyOS wiki pages
  and CachyOS Calamares Limine configuration.
- The installer script passes Bash syntax validation.

Not yet verified:

- Full execution from a CachyOS live ISO.
- Real-hardware boot after installation.
- Post-install Secure Boot.

Do not run this against the real machine until it has been tested in a
disposable environment or you are prepared for a full destructive reinstall.

## Documentation

- [Target configuration](installation/target-configuration.md)
- [Live ISO installer usage](installation/live-iso-installer.md)
- [Post-install Secure Boot](installation/post-install-secure-boot.md)
- [Agent/project context](AGENTS.md)

## Secure Boot

Secure Boot is intentionally not configured by the base install script.

CachyOS recommends installing with Secure Boot disabled. For this Limine-based
target, Secure Boot is tracked separately in
[installation/post-install-secure-boot.md](installation/post-install-secure-boot.md).

## Repository Layout

```text
.
├── AGENTS.md
├── README.md
├── installation/
│   ├── live-iso-installer.md
│   ├── post-install-secure-boot.md
│   └── target-configuration.md
└── scripts/
    └── install-cachyos.sh
```

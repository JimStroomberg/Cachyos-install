#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_MOUNT="/mnt"
BTRFS_OPTS="noatime,compress=zstd,commit=120"
BOOT_LABEL="CACHYBOOT"
ROOT_LABEL="cachyos"
HOSTNAME_DEFAULT="cachyos"
TIMEZONE_DEFAULT="Europe/Amsterdam"
LOCALE_DEFAULT="en_US.UTF-8"
EXTRA_LOCALE="nl_NL.UTF-8"

BASE_PACKAGES=(
  base
  base-devel
  btrfs-progs
  cachyos-hooks
  cachyos-keyring
  cachyos-mirrorlist
  cachyos-v3-mirrorlist
  cachyos-v4-mirrorlist
  cachyos-rate-mirrors
  cachyos-settings
  cachyos-hello
  cachyos-kernel-manager
  cachyos-packageinstaller
  cachyos-micro-settings
  cachyos-wallpapers
  cryptsetup
  device-mapper
  diffutils
  dosfstools
  e2fsprogs
  efibootmgr
  exfatprogs
  f2fs-tools
  limine
  limine-mkinitcpio-hook
  limine-snapper-sync
  cachyos-snapper-support
  snapper
  inetutils
  iptables-nft
  less
  linux-cachyos
  linux-cachyos-headers
  linux-cachyos-lts
  linux-cachyos-lts-headers
  linux-firmware
  logrotate
  lsb-release
  lvm2
  man-db
  man-pages
  mdadm
  chwd
  mkinitcpio
  networkmanager
  netctl
  os-prober
  perl
  python
  s-nail
  sudo
  sysfsutils
  texinfo
  usbutils
  which
  xfsprogs
  plymouth
  cachyos-plymouth-bootanimation
  amd-ucode
  ufw
  bluez
  bluez-utils
  zram-generator
  cachyos-fish-config
  cachyos-zsh-config
)

COMMON_PACKAGES=(
  accountsservice
  alacritty
  alsa-firmware
  alsa-plugins
  alsa-utils
  bash-completion
  btop
  cpupower
  dhclient
  dnsmasq
  dnsutils
  duf
  ethtool
  fastfetch
  ffmpegthumbnailer
  git
  gst-libav
  gst-plugin-pipewire
  gst-plugins-bad
  gst-plugins-ugly
  iwd
  libdvdcss
  mesa-utils
  micro
  nano
  nano-syntax-highlighting
  nss-mdns
  openssh
  pacman-contrib
  paru
  pipewire-alsa
  pipewire-pulse
  pkgfile
  power-profiles-daemon
  rebuild-detector
  reflector
  ripgrep
  rsync
  rtkit
  smartmontools
  unrar
  unzip
  upower
  vim
  vlc-plugins-all
  wget
  wireless-regdb
  wpa_supplicant
  xdg-user-dirs
  xdg-utils
)

KDE_PACKAGES=(
  ark
  bluedevil
  breeze-gtk
  cachyos-emerald-kde-theme-git
  cachyos-iridescent-kde
  cachyos-kde-settings
  cachyos-nord-kde-theme-git
  cachyos-themes-sddm
  dolphin
  egl-wayland
  ffmpegthumbs
  filelight
  fwupd
  gwenview
  haruna
  kate
  kcalc
  kde-gtk-config
  kdeconnect
  kdegraphics-thumbnailers
  kdeplasma-addons
  kdialog
  kinfocenter
  kio-admin
  konsole
  kscreen
  kwallet-pam
  kwalletmanager
  libplasma
  phonon-qt6-vlc
  plasma-browser-integration
  plasma-desktop
  plasma-firewall
  plasma-integration
  plasma-nm
  plasma-pa
  plasma-systemmonitor
  plasma-thunderbolt
  plasma-workspace
  plymouth-kcm
  powerdevil
  qt6-wayland
  sddm
  sddm-kcm
  spectacle
  xdg-desktop-portal
  xdg-desktop-portal-kde
  xorg-server
  xorg-xinit
  xorg-xinput
  xorg-xkill
  xorg-xrandr
  xorg-xwayland
  xsettingsd
)

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\nWARNING: %s\n' "$*" >&2
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  printf '+ %q' "$1"
  shift
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script as root, for example: curl -fsSL <url> | sudo bash"
  fi
}

require_uefi() {
  [[ -d /sys/firmware/efi/efivars ]] || die "This live environment is not booted in UEFI mode."
  efibootmgr -v >/dev/null || die "EFI variables are not available. Reboot the ISO in UEFI mode."
}

require_tty() {
  [[ -r /dev/tty ]] || die "No interactive terminal is available for prompts."
}

require_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    die "Missing required command(s): ${missing[*]}"
  fi
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value
  printf '%s [%s]: ' "$prompt" "$default" >&2
  read -r value < /dev/tty
  printf '%s' "${value:-$default}"
}

prompt_required() {
  local prompt="$1"
  local value
  while true; do
    printf '%s: ' "$prompt" >&2
    if ! read -r value < /dev/tty; then
      die "Could not read from interactive terminal."
    fi
    [[ -n "$value" ]] && {
      printf '%s' "$value"
      return
    }
  done
}

prompt_password() {
  local prompt="$1"
  local first second
  while true; do
    printf '%s: ' "$prompt" >&2
    read -r -s first < /dev/tty
    printf '\n' >&2
    printf 'Confirm %s: ' "$prompt" >&2
    read -r -s second < /dev/tty
    printf '\n' >&2
    if [[ -n "$first" && "$first" == "$second" ]]; then
      printf '%s' "$first"
      return
    fi
    warn "Passwords were empty or did not match. Try again."
  done
}

real_disk() {
  local disk="$1"
  [[ -b "$disk" ]] || die "Not a block device: $disk"
  readlink -f "$disk"
}

partition_path() {
  local disk="$1"
  local number="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$number"
  else
    printf '%s%s' "$disk" "$number"
  fi
}

disk_type() {
  lsblk -dnpo TYPE "$1" 2>/dev/null | awk 'NR == 1 {print $1}'
}

print_disks() {
  lsblk -dpno NAME,SIZE,MODEL,SERIAL,TYPE | sed -n '/ disk$/p'
}

print_disk_ids() {
  if [[ -d /dev/disk/by-id ]]; then
    find /dev/disk/by-id -maxdepth 1 -type l \
      ! -name '*-part*' \
      \( -name 'nvme-*' -o -name 'ata-*' \) \
      -print | sort
  fi
}

suggest_disk() {
  local index="$1"
  local -a candidates
  mapfile -t candidates < <(lsblk -dpno NAME,MODEL,SIZE,TYPE | awk '/Samsung SSD 980 PRO/ && / disk$/ {print $1}')
  if ((${#candidates[@]} >= index)); then
    printf '%s' "${candidates[$((index - 1))]}"
  fi
}

select_disks() {
  local default_disk1 default_disk2 input_disk1 input_disk2
  log "Available disks"
  print_disks
  log "Stable disk identifiers"
  print_disk_ids

  default_disk1="$(suggest_disk 1)"
  default_disk2="$(suggest_disk 2)"

  if [[ -n "$default_disk1" ]]; then
    input_disk1="$(prompt_default "Disk 1, CPU-lane NVMe, will contain /boot + swap + Btrfs" "$default_disk1")"
  else
    input_disk1="$(prompt_required "Disk 1, CPU-lane NVMe, will contain /boot + swap + Btrfs")"
  fi

  if [[ -n "$default_disk2" ]]; then
    input_disk2="$(prompt_default "Disk 2, chipset NVMe, will contain swap + Btrfs" "$default_disk2")"
  else
    input_disk2="$(prompt_required "Disk 2, chipset NVMe, will contain swap + Btrfs")"
  fi

  DISK1="$(real_disk "$input_disk1")"
  DISK2="$(real_disk "$input_disk2")"

  [[ "$DISK1" != "$DISK2" ]] || die "Disk 1 and Disk 2 must be different devices."
  [[ "$(disk_type "$DISK1")" == "disk" ]] || die "$DISK1 is not a whole disk."
  [[ "$(disk_type "$DISK2")" == "disk" ]] || die "$DISK2 is not a whole disk."

  BOOT_PART="$(partition_path "$DISK1" 1)"
  SWAP1_PART="$(partition_path "$DISK1" 2)"
  ROOT1_PART="$(partition_path "$DISK1" 3)"
  SWAP2_PART="$(partition_path "$DISK2" 1)"
  ROOT2_PART="$(partition_path "$DISK2" 2)"
}

confirm_destruction() {
  log "Destructive action summary"
  lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS "$DISK1" "$DISK2"
  cat <<EOF

The script will permanently wipe and repartition:

  Disk 1: $DISK1
    1: /boot FAT32, 4096 MiB
    2: swap, 16384 MiB
    3: Btrfs member, remaining space

  Disk 2: $DISK2
    1: swap, 16384 MiB
    2: Btrfs member, remaining space

EOF
  local answer
  printf 'Type WIPE AND INSTALL to continue: ' >&2
  read -r answer < /dev/tty
  [[ "$answer" == "WIPE AND INSTALL" ]] || die "Confirmation did not match. Aborting."
}

collect_identity() {
  HOSTNAME="$(prompt_default "Hostname" "$HOSTNAME_DEFAULT")"
  USERNAME="$(prompt_required "Primary username")"
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Username must be a normal Linux username."
  TIMEZONE="$(prompt_default "Timezone" "$TIMEZONE_DEFAULT")"
  ROOT_PASSWORD="$(prompt_password "root password")"
  USER_PASSWORD="$(prompt_password "$USERNAME password")"
}

prepare_live_environment() {
  log "Preparing live environment"
  timedatectl set-ntp true || warn "Could not enable NTP in live environment."
  pacman -Sy --noconfirm archlinux-keyring cachyos-keyring || warn "Keyring refresh failed; pacstrap may still work from the ISO state."
  cachyos-rate-mirrors || warn "Mirror ranking failed; continuing with existing mirror configuration."
}

wipe_and_partition() {
  log "Wiping old signatures and partition tables"
  swapoff -a || true
  umount -R "$TARGET_MOUNT" 2>/dev/null || true
  wipefs -af "$DISK1"
  wipefs -af "$DISK2"

  log "Creating GPT partition layout"
  parted -s "$DISK1" mklabel gpt
  parted -s "$DISK1" mkpart primary fat32 1MiB 4097MiB
  parted -s "$DISK1" set 1 boot on
  parted -s "$DISK1" set 1 esp on || true
  parted -s "$DISK1" mkpart primary linux-swap 4097MiB 20481MiB
  parted -s "$DISK1" mkpart primary btrfs 20481MiB 100%

  parted -s "$DISK2" mklabel gpt
  parted -s "$DISK2" mkpart primary linux-swap 1MiB 16385MiB
  parted -s "$DISK2" mkpart primary btrfs 16385MiB 100%

  partprobe "$DISK1" "$DISK2" || true
  udevadm settle

  [[ -b "$BOOT_PART" && -b "$SWAP1_PART" && -b "$ROOT1_PART" && -b "$SWAP2_PART" && -b "$ROOT2_PART" ]] \
    || die "Expected partitions were not created."
}

format_filesystems() {
  log "Formatting partitions"
  mkfs.fat -F 32 -n "$BOOT_LABEL" "$BOOT_PART"
  mkswap -L swap0 "$SWAP1_PART"
  mkswap -L swap1 "$SWAP2_PART"
  mkfs.btrfs -f -L "$ROOT_LABEL" -d single -m raid1 "$ROOT1_PART" "$ROOT2_PART"
}

create_subvolumes() {
  log "Creating CachyOS Btrfs subvolumes"
  mount "$ROOT1_PART" "$TARGET_MOUNT"
  btrfs subvolume create "$TARGET_MOUNT/@"
  btrfs subvolume create "$TARGET_MOUNT/@home"
  btrfs subvolume create "$TARGET_MOUNT/@root"
  btrfs subvolume create "$TARGET_MOUNT/@srv"
  btrfs subvolume create "$TARGET_MOUNT/@cache"
  btrfs subvolume create "$TARGET_MOUNT/@tmp"
  btrfs subvolume create "$TARGET_MOUNT/@log"
  umount "$TARGET_MOUNT"
}

mount_target() {
  log "Mounting target layout"
  mount -o "subvol=@,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT"
  mkdir -p "$TARGET_MOUNT"/{home,root,srv,var/cache,var/tmp,var/log,boot}
  mount -o "subvol=@home,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/home"
  mount -o "subvol=@root,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/root"
  mount -o "subvol=@srv,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/srv"
  mount -o "subvol=@cache,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/var/cache"
  mount -o "subvol=@tmp,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/var/tmp"
  mount -o "subvol=@log,$BTRFS_OPTS" "$ROOT1_PART" "$TARGET_MOUNT/var/log"
  mount -o defaults,umask=0077 "$BOOT_PART" "$TARGET_MOUNT/boot"
  swapon -p 10 "$SWAP1_PART"
  swapon -p 10 "$SWAP2_PART"
}

install_packages() {
  log "Installing CachyOS package baseline and KDE Plasma"
  pacstrap -K "$TARGET_MOUNT" \
    "${BASE_PACKAGES[@]}" \
    "${COMMON_PACKAGES[@]}" \
    "${KDE_PACKAGES[@]}"
}

write_fstab() {
  log "Generating fstab"
  genfstab -U "$TARGET_MOUNT" > "$TARGET_MOUNT/etc/fstab"

  local boot_uuid swap1_uuid swap2_uuid tmp_fstab
  boot_uuid="$(blkid -s UUID -o value "$BOOT_PART")"
  swap1_uuid="$(blkid -s UUID -o value "$SWAP1_PART")"
  swap2_uuid="$(blkid -s UUID -o value "$SWAP2_PART")"
  tmp_fstab="$(mktemp)"

  awk -v boot_uuid="$boot_uuid" -v swap1_uuid="$swap1_uuid" -v swap2_uuid="$swap2_uuid" '
    BEGIN { OFS="\t" }
    $1 == "UUID=" boot_uuid && $2 == "/boot" && $3 == "vfat" { $4 = "defaults,umask=0077" }
    ($1 == "UUID=" swap1_uuid || $1 == "UUID=" swap2_uuid) && $3 == "swap" { $4 = "defaults,pri=10" }
    { print }
  ' "$TARGET_MOUNT/etc/fstab" > "$tmp_fstab"

  cat "$tmp_fstab" > "$TARGET_MOUNT/etc/fstab"
  rm -f "$tmp_fstab"
}

configure_system() {
  log "Configuring installed system"

  arch-chroot "$TARGET_MOUNT" ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  arch-chroot "$TARGET_MOUNT" hwclock --systohc

  sed -i "s/^#\?$LOCALE_DEFAULT UTF-8/$LOCALE_DEFAULT UTF-8/" "$TARGET_MOUNT/etc/locale.gen"
  sed -i "s/^#\?$EXTRA_LOCALE UTF-8/$EXTRA_LOCALE UTF-8/" "$TARGET_MOUNT/etc/locale.gen"
  arch-chroot "$TARGET_MOUNT" locale-gen
  printf 'LANG=%s\n' "$LOCALE_DEFAULT" > "$TARGET_MOUNT/etc/locale.conf"

  printf '%s\n' "$HOSTNAME" > "$TARGET_MOUNT/etc/hostname"
  cat > "$TARGET_MOUNT/etc/hosts" <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

  arch-chroot "$TARGET_MOUNT" useradd -m -G wheel,audio,video,input,storage,lp -s /bin/bash "$USERNAME"
  {
    printf 'root:%s\n' "$ROOT_PASSWORD"
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD"
  } | arch-chroot "$TARGET_MOUNT" chpasswd

  install -d -m 0750 "$TARGET_MOUNT/etc/sudoers.d"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$TARGET_MOUNT/etc/sudoers.d/10-wheel"
  chmod 0440 "$TARGET_MOUNT/etc/sudoers.d/10-wheel"

  arch-chroot "$TARGET_MOUNT" systemctl enable NetworkManager
  arch-chroot "$TARGET_MOUNT" systemctl enable systemd-timesyncd
  arch-chroot "$TARGET_MOUNT" systemctl enable fstrim.timer
  arch-chroot "$TARGET_MOUNT" systemctl enable bluetooth
  arch-chroot "$TARGET_MOUNT" systemctl enable ufw
  arch-chroot "$TARGET_MOUNT" systemctl enable sddm
  arch-chroot "$TARGET_MOUNT" ufw --force enable || warn "ufw enable failed; service is still enabled."
  arch-chroot "$TARGET_MOUNT" chwd -a || warn "chwd hardware detection failed; AMD/Mesa defaults may still be sufficient."
}

configure_limine() {
  log "Configuring Limine"
  local root_uuid
  root_uuid="$(blkid -s UUID -o value "$ROOT1_PART")"

  install -d "$TARGET_MOUNT/etc/default"
  cat > "$TARGET_MOUNT/etc/default/limine" <<EOF
ESP_PATH="/boot"
KERNEL_CMDLINE[default]="quiet nowatchdog splash rw root=UUID=$root_uuid rootflags=subvol=@"
BOOT_ORDER="*, *lts, *fallback, Snapshots"
EOF

  cat > "$TARGET_MOUNT/boot/limine.conf" <<'EOF'
timeout: 5
default_entry: 2
remember_last_entry: yes

/+CachyOS
EOF

  arch-chroot "$TARGET_MOUNT" mkinitcpio -P
  arch-chroot "$TARGET_MOUNT" limine-install
  arch-chroot "$TARGET_MOUNT" limine-update

  if [[ -e "$TARGET_MOUNT/etc/limine-snapper-sync.conf" ]]; then
    sed -i 's/TARGET_OS_NAME=".*"/TARGET_OS_NAME="CachyOS"/' "$TARGET_MOUNT/etc/limine-snapper-sync.conf"
    arch-chroot "$TARGET_MOUNT" systemctl enable limine-snapper-sync.service || true
  fi

  add_limine_boot_entry
}

add_limine_boot_entry() {
  log "Ensuring UEFI boot entry exists"
  if [[ -f "$TARGET_MOUNT/boot/EFI/BOOT/BOOTX64.EFI" ]]; then
    efibootmgr -c -d "$DISK1" -p 1 -L "CachyOS" -l '\EFI\BOOT\BOOTX64.EFI' \
      || warn "Could not create UEFI NVRAM entry. Firmware fallback path may still boot."
  else
    warn "Limine fallback EFI binary not found at /boot/EFI/BOOT/BOOTX64.EFI; skipping efibootmgr fallback."
  fi
}

verify_installation() {
  log "Verification output"
  lsblk -f "$DISK1" "$DISK2"
  findmnt "$TARGET_MOUNT/boot" || true
  findmnt "$TARGET_MOUNT" || true
  btrfs filesystem show "$TARGET_MOUNT" || true
  btrfs filesystem usage "$TARGET_MOUNT" || true
  swapon --show || true
  printf '\n--- target /etc/fstab ---\n'
  cat "$TARGET_MOUNT/etc/fstab"
  printf '\n--- target /etc/default/limine ---\n'
  cat "$TARGET_MOUNT/etc/default/limine"
  printf '\n--- target /boot ---\n'
  find "$TARGET_MOUNT/boot" -maxdepth 3 -type f | sort
}

main() {
  require_root
  require_tty
  require_commands awk blkid btrfs cachyos-rate-mirrors efibootmgr findmnt genfstab lsblk mkfs.btrfs mkfs.fat mkswap pacman pacstrap parted partprobe readlink sed swapon udevadm wipefs arch-chroot
  require_uefi
  select_disks
  collect_identity
  confirm_destruction
  prepare_live_environment
  wipe_and_partition
  format_filesystems
  create_subvolumes
  mount_target
  install_packages
  write_fstab
  configure_system
  configure_limine
  verify_installation

  log "Installation complete"
  cat <<EOF

Review the verification output above before rebooting.

To reboot:

  swapoff -a
  umount -R $TARGET_MOUNT
  reboot

Secure Boot remains disabled by design. Configure it later using:

  installation/post-install-secure-boot.md

EOF
}

main "$@"

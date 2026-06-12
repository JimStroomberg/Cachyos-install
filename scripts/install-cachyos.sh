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
BOOT_SIZE_MIB=4096
SWAP_PRIORITY=10
REPO_URL="https://github.com/JimStroomberg/Cachyos-install"

MODE="install"
NO_TUI=0
TUI_CMD=""
LOG_FILE=""

declare -a SELECTED_DISKS=()
declare -a ROOT_PARTS=()
declare -a SWAP_PARTS=()

BOOT_DISK=""
BOOT_PART=""
BTRFS_METADATA_PROFILE=""
HOSTNAME=""
USERNAME=""
TIMEZONE=""
ROOT_PASSWORD=""
USER_PASSWORD=""
SWAP_CHOICE=""
SWAP_TOTAL_MIB=0
SWAP_PER_DISK_MIB=0

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

DESKTOP_APP_PACKAGES=(
  firefox
  flatpak
)

GAMING_PACKAGES=(
  steam
  steam-devices
  mesa
  lib32-mesa
  vulkan-radeon
  lib32-vulkan-radeon
  vulkan-tools
  gamescope
  mangohud
  goverlay
  wine
  wine-gecko
  wine-mono
  winetricks
  protontricks
  umu-launcher
)

FAUGUS_DEPENDENCY_PACKAGES=(
  python-gobject
  python-requests
  python-pillow
  python-vdf
  python-psutil
  python-pygame
  python-cairo
  libcanberra
  imagemagick
  icoextract
  libayatana-appindicator
  meson
  ninja
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

usage() {
  cat <<EOF
CachyOS beginner-friendly gaming installer

Usage:
  sudo bash scripts/install-cachyos.sh --preflight
  sudo bash scripts/install-cachyos.sh --install
  sudo bash scripts/install-cachyos.sh --install --no-tui
  bash scripts/install-cachyos.sh --help

Modes:
  --preflight   Print a non-destructive environment and hardware report.
  --install     Run the guided destructive installer.
  --self-test   Run non-destructive calculation tests.
  --help        Show this help text.

This installer is for fresh CachyOS installs on UEFI AMD-oriented gaming PCs.
It creates one large Btrfs capacity pool. Extra disks add storage, not data
redundancy. If any pool disk fails, user data may be lost. Keep backups.

Not implemented in v1:
  - dual-boot resizing
  - full-disk encryption
  - NVIDIA-specific tuning
  - Secure Boot setup during base install

Project documentation:
  $REPO_URL
EOF
}

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

parse_args() {
  while (($#)); do
    case "$1" in
      --preflight)
        MODE="preflight"
        ;;
      --install)
        MODE="install"
        ;;
      --self-test)
        MODE="self-test"
        ;;
      --no-tui)
        NO_TUI=1
        ;;
      -h|--help)
        MODE="help"
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

setup_logging() {
  local live_user live_home log_dir timestamp
  live_user="${SUDO_USER:-}"

  if [[ -n "$live_user" && "$live_user" != "root" ]]; then
    live_home="$(getent passwd "$live_user" | cut -d: -f6 || true)"
  else
    live_home=""
  fi

  if [[ -z "$live_home" && -d /home/cachyos ]]; then
    live_user="cachyos"
    live_home="/home/cachyos"
  fi

  if [[ -n "$live_home" && -d "$live_home" ]]; then
    log_dir="$live_home/Desktop"
    mkdir -p "$log_dir"
  else
    log_dir="/tmp"
  fi

  timestamp="$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="$log_dir/cachyos-install-$timestamp.log"
  touch "$LOG_FILE"

  if [[ -n "$live_user" && "$live_user" != "root" ]]; then
    chown "$live_user":"$live_user" "$LOG_FILE" 2>/dev/null || true
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1
  log "Logging to $LOG_FILE"
}

on_exit() {
  local status="$1"
  if [[ -z "${LOG_FILE:-}" ]]; then
    return
  fi

  if [[ "$status" -eq 0 ]]; then
    log "Installer finished successfully. Full log: $LOG_FILE"
  else
    warn "Installer exited with status $status. Full log: $LOG_FILE"
    printf '\n--- Last 80 log lines ---\n'
    tail -n 80 "$LOG_FILE" || true
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script as root, for example: sudo bash scripts/install-cachyos.sh --install"
  fi
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

require_uefi() {
  [[ -d /sys/firmware/efi/efivars ]] || die "This live environment is not booted in UEFI mode."
  efibootmgr -v >/dev/null || die "EFI variables are not available. Reboot the ISO in UEFI mode."
}

init_tui() {
  TUI_CMD=""
  if [[ "$NO_TUI" -eq 1 || ! -r /dev/tty ]]; then
    return
  fi
  if command -v dialog >/dev/null 2>&1; then
    TUI_CMD="dialog"
  elif command -v whiptail >/dev/null 2>&1; then
    TUI_CMD="whiptail"
  fi
}

ensure_tui_backend() {
  init_tui
  if [[ "$NO_TUI" -eq 1 ]]; then
    return
  fi
  if [[ "$TUI_CMD" == "dialog" ]]; then
    return
  fi

  log "Trying to ensure dialog is available for guided terminal menus."
  if pacman -Sy --needed --noconfirm dialog; then
    init_tui
  else
    warn "Could not install dialog. Falling back to whiptail if available, otherwise numbered prompts."
  fi
}

announce_interaction_mode() {
  if [[ -n "$TUI_CMD" ]]; then
    log "Using $TUI_CMD for guided terminal menus."
  else
    log "Using numbered prompts. Type the number for each choice and press Enter; arrow keys are not used in this mode."
  fi
}

run_tui() {
  "$TUI_CMD" "$@" < /dev/tty 3>&1 1>/dev/tty 2>&3
}

tui_msg() {
  local title="$1"
  local message="$2"
  printf '\n%s\n%s\n' "$title" "$message" >&2
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value

  if [[ -n "$TUI_CMD" ]]; then
    value="$(run_tui --inputbox "$prompt" 10 70 "$default")" || die "Prompt cancelled."
    printf '%s' "${value:-$default}"
    return
  fi

  printf '%s [%s]: ' "$prompt" "$default" >&2
  read -r value < /dev/tty
  printf '%s' "${value:-$default}"
}

prompt_required() {
  local prompt="$1"
  local value
  while true; do
    if [[ -n "$TUI_CMD" ]]; then
      value="$(run_tui --inputbox "$prompt" 10 70)" || die "Prompt cancelled."
    else
      printf '%s: ' "$prompt" >&2
      read -r value < /dev/tty || die "Could not read from interactive terminal."
    fi
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi
    warn "A value is required."
  done
}

prompt_password() {
  local prompt="$1"
  local first second
  while true; do
    if [[ -n "$TUI_CMD" ]]; then
      first="$(run_tui --passwordbox "$prompt" 10 70)" || die "Prompt cancelled."
      second="$(run_tui --passwordbox "Confirm $prompt" 10 70)" || die "Prompt cancelled."
    else
      printf '%s: ' "$prompt" >&2
      read -r -s first < /dev/tty
      printf '\n' >&2
      printf 'Confirm %s: ' "$prompt" >&2
      read -r -s second < /dev/tty
      printf '\n' >&2
    fi
    if [[ -n "$first" && "$first" == "$second" ]]; then
      printf '%s' "$first"
      return
    fi
    warn "Passwords were empty or did not match. Try again."
  done
}

read_mem_total_mib() {
  if [[ -r /proc/meminfo ]]; then
    awk '/^MemTotal:/ { print int(($2 + 1023) / 1024) }' /proc/meminfo
  else
    printf '0'
  fi
}

recommended_swap_total_mib() {
  local mem_kib
  if [[ -r /proc/meminfo ]]; then
    mem_kib="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)"
    printf '%d' $(( ((mem_kib + 1048576 - 1) * 1024) / 1048576 ))
  else
    printf '32768'
  fi
}

metadata_profile_for_disk_count() {
  local disk_count="$1"
  if ((disk_count > 1)); then
    printf 'raid1'
  else
    printf 'dup'
  fi
}

swap_per_disk_mib() {
  local total_mib="$1"
  local disk_count="$2"
  if ((total_mib == 0)); then
    printf '0'
  else
    printf '%d' $((total_mib / disk_count))
  fi
}

self_test() {
  local failed=0
  [[ "$(metadata_profile_for_disk_count 1)" == "dup" ]] || failed=1
  [[ "$(metadata_profile_for_disk_count 2)" == "raid1" ]] || failed=1
  [[ "$(metadata_profile_for_disk_count 4)" == "raid1" ]] || failed=1
  [[ "$(swap_per_disk_mib 32768 1)" == "32768" ]] || failed=1
  [[ "$(swap_per_disk_mib 32768 2)" == "16384" ]] || failed=1
  [[ "$(swap_per_disk_mib 32768 3)" == "10922" ]] || failed=1
  [[ "$(swap_per_disk_mib 0 3)" == "0" ]] || failed=1

  if ((failed)); then
    die "Self-test failed."
  fi
  log "Self-test passed."
}

disk_type() {
  lsblk -dnpo TYPE "$1" 2>/dev/null | awk 'NR == 1 {print $1}'
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

available_disk_names() {
  lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2 == "disk" {print $1}'
}

disk_description() {
  local disk="$1"
  local desc
  desc="$(lsblk -dnpo SIZE,MODEL,SERIAL "$disk" 2>/dev/null | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  printf '%s %s' "$disk" "$desc"
}

print_disks() {
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -dpno NAME,SIZE,MODEL,SERIAL,TYPE | sed -n '/ disk$/p'
  else
    warn "lsblk is not available."
  fi
}

print_disk_ids() {
  if [[ -d /dev/disk/by-id ]]; then
    find /dev/disk/by-id -maxdepth 1 -type l \
      ! -name '*-part*' \
      \( -name 'nvme-*' -o -name 'ata-*' -o -name 'scsi-*' \) \
      -print | sort
  else
    warn "/dev/disk/by-id is not available."
  fi
}

select_boot_disk_tui() {
  local -a disks=("$@")
  local -a items=()
  local disk
  for disk in "${disks[@]}"; do
    items+=("$disk" "$(disk_description "$disk")")
  done
  run_tui --title "Boot disk" --menu "Select the disk that will contain /boot. This disk will be wiped." 22 86 12 "${items[@]}"
}

select_extra_disks_tui() {
  local boot_disk="$1"
  shift
  local -a items=()
  local disk
  for disk in "$@"; do
    if [[ "$disk" != "$boot_disk" ]]; then
      items+=("$disk" "$(disk_description "$disk")" "off")
    fi
  done
  if ((${#items[@]} == 0)); then
    return 0
  fi
  run_tui --title "Additional pool disks" --checklist "Select extra disks to add to the Btrfs capacity pool. Every selected disk will be wiped." 22 86 12 "${items[@]}" | tr -d '"'
}

select_boot_disk_plain() {
  local -a disks=("$@")
  local choice
  local i
  printf '\nNumbered prompt mode: type a disk number and press Enter. Arrow keys are not used here.\n' >&2
  printf '\nAvailable disks:\n' >&2
  for i in "${!disks[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "$(disk_description "${disks[$i]}")" >&2
  done
  while true; do
    printf 'Select boot disk number: ' >&2
    read -r choice < /dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#disks[@]})); then
      printf '%s' "${disks[$((choice - 1))]}"
      return
    fi
    warn "Invalid disk selection."
  done
}

select_extra_disks_plain() {
  local boot_disk="$1"
  shift
  local -a disks=("$@")
  local -a selectable=()
  local answer token
  local i

  for i in "${!disks[@]}"; do
    if [[ "${disks[$i]}" != "$boot_disk" ]]; then
      selectable+=("${disks[$i]}")
    fi
  done

  if ((${#selectable[@]} == 0)); then
    return 0
  fi

  printf '\nAdditional disks can be added to the Btrfs capacity pool.\n' >&2
  printf 'These disks add storage, not redundancy. Leave empty for no extra disks.\n' >&2
  for i in "${!selectable[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "$(disk_description "${selectable[$i]}")" >&2
  done
  printf 'Select extra disk numbers separated by spaces or commas: ' >&2
  read -r answer < /dev/tty
  answer="${answer//,/ }"
  for token in $answer; do
    if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= ${#selectable[@]})); then
      printf '%s\n' "${selectable[$((token - 1))]}"
    else
      die "Invalid additional disk selection: $token"
    fi
  done
}

dedupe_selected_disks() {
  local -A seen=()
  local -a deduped=()
  local disk real
  for disk in "$@"; do
    [[ -z "$disk" ]] && continue
    real="$(real_disk "$disk")"
    [[ "$(disk_type "$real")" == "disk" ]] || die "$real is not a whole disk."
    if [[ -z "${seen[$real]:-}" ]]; then
      seen[$real]=1
      deduped+=("$real")
    fi
  done
  SELECTED_DISKS=("${deduped[@]}")
}

select_disks() {
  local -a disks extra_disks=()
  local boot_disk extra_output disk

  log "Available disks"
  print_disks
  log "Stable disk identifiers"
  print_disk_ids

  mapfile -t disks < <(available_disk_names)
  ((${#disks[@]} >= 1)) || die "No whole disks were detected."

  if [[ -n "$TUI_CMD" ]]; then
    boot_disk="$(select_boot_disk_tui "${disks[@]}")" || die "Boot disk selection cancelled."
    extra_output="$(select_extra_disks_tui "$boot_disk" "${disks[@]}")" || die "Additional disk selection cancelled."
    for disk in $extra_output; do
      extra_disks+=("$disk")
    done
  else
    boot_disk="$(select_boot_disk_plain "${disks[@]}")"
    mapfile -t extra_disks < <(select_extra_disks_plain "$boot_disk" "${disks[@]}")
  fi

  dedupe_selected_disks "$boot_disk" "${extra_disks[@]}"
  ((${#SELECTED_DISKS[@]} >= 1)) || die "At least one disk must be selected."
  BOOT_DISK="${SELECTED_DISKS[0]}"
}

select_swap_policy_tui() {
  local recommended_gib="$1"
  run_tui --title "Disk swap" --menu "CachyOS ZRAM remains the primary swap layer. Choose lower-priority disk swap." 18 78 8 \
    recommended "Recommended: ${recommended_gib} GiB total, split across selected disks" \
    none "No disk swap partitions" \
    custom "Enter a custom total disk swap size"
}

select_swap_policy_plain() {
  local recommended_gib="$1"
  local choice
  printf '\nDisk swap options:\n' >&2
  printf '  1) Recommended: %s GiB total, split across selected disks\n' "$recommended_gib" >&2
  printf '  2) No disk swap partitions\n' >&2
  printf '  3) Custom total disk swap size\n' >&2
  while true; do
    printf 'Choose swap option [1]: ' >&2
    read -r choice < /dev/tty
    case "${choice:-1}" in
      1) printf 'recommended'; return ;;
      2) printf 'none'; return ;;
      3) printf 'custom'; return ;;
      *) warn "Invalid swap option." ;;
    esac
  done
}

collect_swap_policy() {
  local recommended_total recommended_gib custom_gib disk_count
  disk_count="${#SELECTED_DISKS[@]}"
  recommended_total="$(recommended_swap_total_mib)"
  recommended_gib="$((recommended_total / 1024))"

  if [[ -n "$TUI_CMD" ]]; then
    SWAP_CHOICE="$(select_swap_policy_tui "$recommended_gib")" || die "Swap selection cancelled."
  else
    SWAP_CHOICE="$(select_swap_policy_plain "$recommended_gib")"
  fi

  case "$SWAP_CHOICE" in
    recommended)
      SWAP_TOTAL_MIB="$recommended_total"
      ;;
    none)
      SWAP_TOTAL_MIB=0
      ;;
    custom)
      custom_gib="$(prompt_required "Custom total disk swap size in GiB")"
      [[ "$custom_gib" =~ ^[0-9]+$ && "$custom_gib" -gt 0 ]] || die "Custom swap size must be a positive whole GiB value."
      SWAP_TOTAL_MIB="$((custom_gib * 1024))"
      ;;
    *)
      die "Unknown swap choice: $SWAP_CHOICE"
      ;;
  esac

  SWAP_PER_DISK_MIB="$(swap_per_disk_mib "$SWAP_TOTAL_MIB" "$disk_count")"
  if ((SWAP_TOTAL_MIB > 0 && SWAP_PER_DISK_MIB < 1024)); then
    die "Swap per disk would be less than 1 GiB. Choose a larger total swap size or no disk swap."
  fi
}

collect_identity() {
  HOSTNAME="$(prompt_default "Hostname" "$HOSTNAME_DEFAULT")"
  USERNAME="$(prompt_required "Primary username")"
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Username must be a normal Linux username."
  TIMEZONE="$(prompt_default "Timezone" "$TIMEZONE_DEFAULT")"
  ROOT_PASSWORD="$(prompt_password "root password")"
  USER_PASSWORD="$(prompt_password "$USERNAME password")"
}

build_partition_plan() {
  local disk_count disk root_part swap_part
  disk_count="${#SELECTED_DISKS[@]}"
  BTRFS_METADATA_PROFILE="$(metadata_profile_for_disk_count "$disk_count")"
  BOOT_PART="$(partition_path "$BOOT_DISK" 1)"
  ROOT_PARTS=()
  SWAP_PARTS=()

  for disk in "${SELECTED_DISKS[@]}"; do
    if [[ "$disk" == "$BOOT_DISK" ]]; then
      if ((SWAP_PER_DISK_MIB > 0)); then
        swap_part="$(partition_path "$disk" 2)"
        root_part="$(partition_path "$disk" 3)"
        SWAP_PARTS+=("$swap_part")
      else
        root_part="$(partition_path "$disk" 2)"
      fi
    else
      if ((SWAP_PER_DISK_MIB > 0)); then
        swap_part="$(partition_path "$disk" 1)"
        root_part="$(partition_path "$disk" 2)"
        SWAP_PARTS+=("$swap_part")
      else
        root_part="$(partition_path "$disk" 1)"
      fi
    fi
    ROOT_PARTS+=("$root_part")
  done
}

print_install_plan() {
  local disk root_index=0
  cat <<EOF

Target install plan
===================

Boot disk:
  $BOOT_DISK

Selected Btrfs pool disks:
EOF
  for disk in "${SELECTED_DISKS[@]}"; do
    printf '  - %s\n' "$disk"
  done

  cat <<EOF

Btrfs profile:
  Data:     single
  Metadata: $BTRFS_METADATA_PROFILE
  System:   $BTRFS_METADATA_PROFILE

Important:
  Extra disks add capacity, not data redundancy.
  If any selected pool disk fails, data in the pool may be lost.
  Keep backups on separate storage.

Partition plan:
EOF

  for disk in "${SELECTED_DISKS[@]}"; do
    printf '  %s\n' "$disk"
    if [[ "$disk" == "$BOOT_DISK" ]]; then
      printf '    1: /boot FAT32, %s MiB\n' "$BOOT_SIZE_MIB"
      if ((SWAP_PER_DISK_MIB > 0)); then
        printf '    2: swap, %s MiB\n' "$SWAP_PER_DISK_MIB"
        printf '    3: Btrfs member, remaining space -> %s\n' "${ROOT_PARTS[$root_index]}"
      else
        printf '    2: Btrfs member, remaining space -> %s\n' "${ROOT_PARTS[$root_index]}"
      fi
    else
      if ((SWAP_PER_DISK_MIB > 0)); then
        printf '    1: swap, %s MiB\n' "$SWAP_PER_DISK_MIB"
        printf '    2: Btrfs member, remaining space -> %s\n' "${ROOT_PARTS[$root_index]}"
      else
        printf '    1: Btrfs member, remaining space -> %s\n' "${ROOT_PARTS[$root_index]}"
      fi
    fi
    root_index=$((root_index + 1))
  done

  if ((SWAP_PER_DISK_MIB > 0)); then
    printf '\nDisk swap:\n  %s MiB total target, %s MiB per selected disk, priority %s\n' "$SWAP_TOTAL_MIB" "$SWAP_PER_DISK_MIB" "$SWAP_PRIORITY"
  else
    printf '\nDisk swap:\n  No disk swap partitions. CachyOS ZRAM remains enabled by default.\n'
  fi
  printf '\n'
}

confirm_destruction() {
  log "Destructive action summary"
  lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS "${SELECTED_DISKS[@]}"
  print_install_plan

  if [[ -n "$TUI_CMD" ]]; then
    run_tui --title "Final destructive confirmation" --yesno "The selected disks will be wiped. Extra disks add capacity, not redundancy. Backups are required.\n\nContinue to typed confirmation?" 16 78 \
      || die "Installation cancelled."
  fi

  local answer
  printf 'Type WIPE AND INSTALL to continue: ' >&2
  read -r answer < /dev/tty
  [[ "$answer" == "WIPE AND INSTALL" ]] || die "Confirmation did not match. Aborting."
}

prepare_live_environment() {
  log "Preparing live environment"
  timedatectl set-ntp true || warn "Could not enable NTP in live environment."
  pacman -Sy --noconfirm archlinux-keyring cachyos-keyring || warn "Keyring refresh failed; pacstrap may still work from the ISO state."
  cachyos-rate-mirrors || warn "Mirror ranking failed; continuing with existing mirror configuration."
}

wipe_and_partition() {
  local disk start_mib swap_end_mib
  log "Wiping old signatures and partition tables"
  swapoff -a || true
  umount -R "$TARGET_MOUNT" 2>/dev/null || true

  for disk in "${SELECTED_DISKS[@]}"; do
    wipefs -af "$disk"
  done

  log "Creating GPT partition layout"
  for disk in "${SELECTED_DISKS[@]}"; do
    parted -s "$disk" mklabel gpt
    if [[ "$disk" == "$BOOT_DISK" ]]; then
      parted -s "$disk" mkpart primary fat32 1MiB "$((BOOT_SIZE_MIB + 1))MiB"
      parted -s "$disk" set 1 boot on
      parted -s "$disk" set 1 esp on || true
      start_mib="$((BOOT_SIZE_MIB + 1))"
      if ((SWAP_PER_DISK_MIB > 0)); then
        swap_end_mib="$((start_mib + SWAP_PER_DISK_MIB))"
        parted -s "$disk" mkpart primary linux-swap "${start_mib}MiB" "${swap_end_mib}MiB"
        parted -s "$disk" mkpart primary btrfs "${swap_end_mib}MiB" 100%
      else
        parted -s "$disk" mkpart primary btrfs "${start_mib}MiB" 100%
      fi
    else
      if ((SWAP_PER_DISK_MIB > 0)); then
        swap_end_mib="$((1 + SWAP_PER_DISK_MIB))"
        parted -s "$disk" mkpart primary linux-swap 1MiB "${swap_end_mib}MiB"
        parted -s "$disk" mkpart primary btrfs "${swap_end_mib}MiB" 100%
      else
        parted -s "$disk" mkpart primary btrfs 1MiB 100%
      fi
    fi
  done

  partprobe "${SELECTED_DISKS[@]}" || true
  udevadm settle

  [[ -b "$BOOT_PART" ]] || die "Expected boot partition was not created: $BOOT_PART"
  for disk in "${ROOT_PARTS[@]}" "${SWAP_PARTS[@]}"; do
    [[ -b "$disk" ]] || die "Expected partition was not created: $disk"
  done
}

format_filesystems() {
  local i
  log "Formatting partitions"
  mkfs.fat -F 32 -n "$BOOT_LABEL" "$BOOT_PART"

  for i in "${!SWAP_PARTS[@]}"; do
    mkswap -L "swap$i" "${SWAP_PARTS[$i]}"
  done

  mkfs.btrfs -f -L "$ROOT_LABEL" -d single -m "$BTRFS_METADATA_PROFILE" "${ROOT_PARTS[@]}"
}

create_subvolumes() {
  log "Creating CachyOS Btrfs subvolumes"
  mount "${ROOT_PARTS[0]}" "$TARGET_MOUNT"
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
  local swap_part
  log "Mounting target layout"
  mount -o "subvol=@,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT"
  mkdir -p "$TARGET_MOUNT"/{home,root,srv,var/cache,var/tmp,var/log,boot}
  mount -o "subvol=@home,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/home"
  mount -o "subvol=@root,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/root"
  mount -o "subvol=@srv,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/srv"
  mount -o "subvol=@cache,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/var/cache"
  mount -o "subvol=@tmp,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/var/tmp"
  mount -o "subvol=@log,$BTRFS_OPTS" "${ROOT_PARTS[0]}" "$TARGET_MOUNT/var/log"
  mount -o defaults,umask=0077 "$BOOT_PART" "$TARGET_MOUNT/boot"

  for swap_part in "${SWAP_PARTS[@]}"; do
    swapon -p "$SWAP_PRIORITY" "$swap_part"
  done
}

install_packages() {
  log "Installing CachyOS package baseline and KDE Plasma"
  pacstrap -K "$TARGET_MOUNT" \
    "${BASE_PACKAGES[@]}" \
    "${COMMON_PACKAGES[@]}" \
    "${DESKTOP_APP_PACKAGES[@]}" \
    "${GAMING_PACKAGES[@]}" \
    "${FAUGUS_DEPENDENCY_PACKAGES[@]}" \
    "${KDE_PACKAGES[@]}"
}

copy_pacman_configuration() {
  log "Copying CachyOS pacman repository configuration"
  install -m 0644 /etc/pacman.conf "$TARGET_MOUNT/etc/pacman.conf"
  if [[ -f /etc/pacman-more.conf ]]; then
    install -m 0644 /etc/pacman-more.conf "$TARGET_MOUNT/etc/pacman-more.conf"
  fi

  sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$TARGET_MOUNT/etc/pacman.conf"
  if ! grep -q '^\[multilib\]' "$TARGET_MOUNT/etc/pacman.conf"; then
    cat >> "$TARGET_MOUNT/etc/pacman.conf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
  fi

  arch-chroot "$TARGET_MOUNT" pacman -Sy --noconfirm
  arch-chroot "$TARGET_MOUNT" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo \
    || warn "Could not add Flathub remote. Flatpak can be configured after first boot."
}

write_fstab() {
  log "Generating fstab"
  genfstab -U "$TARGET_MOUNT" > "$TARGET_MOUNT/etc/fstab"

  local boot_uuid tmp_fstab
  boot_uuid="$(blkid -s UUID -o value "$BOOT_PART")"
  tmp_fstab="$(mktemp)"

  awk -v boot_uuid="$boot_uuid" -v swap_priority="$SWAP_PRIORITY" '
    BEGIN { OFS="\t" }
    $3 == "btrfs" {
      subvol = ""
      count = split($4, opts, ",")
      for (i = 1; i <= count; i++) {
        if (opts[i] ~ /^subvol=/) {
          subvol = opts[i]
        }
      }
      if (subvol != "") {
        $4 = "defaults,noatime,compress=zstd,commit=120," subvol
      }
    }
    $1 == "UUID=" boot_uuid && $2 == "/boot" && $3 == "vfat" { $4 = "defaults,umask=0077" }
    $3 == "swap" { $4 = "defaults,pri=" swap_priority }
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
  root_uuid="$(blkid -s UUID -o value "${ROOT_PARTS[0]}")"

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
    efibootmgr -c -d "$BOOT_DISK" -p 1 -L "CachyOS" -l '\EFI\BOOT\BOOTX64.EFI' \
      || warn "Could not create UEFI NVRAM entry. Firmware fallback path may still boot."
  else
    warn "Limine fallback EFI binary not found at /boot/EFI/BOOT/BOOTX64.EFI; skipping efibootmgr fallback."
  fi
}

verify_installation() {
  log "Verification output"
  lsblk -f "${SELECTED_DISKS[@]}"
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

secure_boot_state() {
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state 2>/dev/null | head -n 1 || true
  elif [[ -d /sys/firmware/efi/efivars ]]; then
    local file
    file="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' 2>/dev/null | head -n 1)"
    if [[ -n "$file" ]] && command -v od >/dev/null 2>&1; then
      if [[ "$(od -An -t u1 -j 4 -N 1 "$file" 2>/dev/null | tr -d ' ')" == "1" ]]; then
        printf 'SecureBoot enabled'
      else
        printf 'SecureBoot disabled'
      fi
    else
      printf 'Unknown'
    fi
  else
    printf 'Unavailable outside UEFI'
  fi
}

print_preflight_check() {
  local label="$1"
  local status="$2"
  local detail="$3"
  printf '%-28s %-8s %s\n' "$label" "$status" "$detail"
}

run_preflight() {
  local missing=()
  local required=(
    awk blkid btrfs cachyos-rate-mirrors efibootmgr findmnt genfstab lsblk mkfs.btrfs
    mkfs.fat mkswap pacman pacstrap parted partprobe readlink sed swapon udevadm wipefs arch-chroot
  )
  local cmd
  local os_name="unknown"
  local tui="plain prompts"

  init_tui
  [[ -n "$TUI_CMD" ]] && tui="$TUI_CMD"

  if [[ -r /etc/os-release ]]; then
    os_name="$(awk -F= '/^PRETTY_NAME=/ {gsub(/"/, "", $2); print $2}' /etc/os-release)"
  fi

  for cmd in "${required[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  log "CachyOS installer preflight report"
  print_preflight_check "Running as root" "$([[ ${EUID} -eq 0 ]] && printf OK || printf WARN)" "installer needs root for --install"
  print_preflight_check "Interactive terminal" "$([[ -r /dev/tty ]] && printf OK || printf FAIL)" "/dev/tty required for guided install"
  print_preflight_check "Operating system" "INFO" "$os_name"
  print_preflight_check "UEFI boot" "$([[ -d /sys/firmware/efi/efivars ]] && printf OK || printf FAIL)" "/sys/firmware/efi/efivars"
  if command -v efibootmgr >/dev/null 2>&1 && efibootmgr -v >/dev/null 2>&1; then
    print_preflight_check "EFI variables" "OK" "efibootmgr can read NVRAM"
  else
    print_preflight_check "EFI variables" "WARN" "not available or efibootmgr missing"
  fi
  print_preflight_check "Secure Boot" "INFO" "$(secure_boot_state)"
  print_preflight_check "RAM" "INFO" "$(read_mem_total_mib) MiB detected"
  print_preflight_check "TUI" "INFO" "$tui"

  if command -v lspci >/dev/null 2>&1; then
    print_preflight_check "GPU" "INFO" "$(lspci | awk '/VGA|3D|Display/ {print; found=1} END {if (!found) print "not detected"}')"
    if lspci | grep -Eiq 'VGA|3D|Display' && lspci | grep -Eiq 'NVIDIA'; then
      print_preflight_check "NVIDIA" "WARN" "v1 does not implement NVIDIA-specific tuning"
    fi
  else
    print_preflight_check "GPU" "WARN" "lspci not available"
  fi

  if command -v ping >/dev/null 2>&1 && ping -c 1 -W 2 cachyos.org >/dev/null 2>&1; then
    print_preflight_check "Network" "OK" "cachyos.org reachable"
  else
    print_preflight_check "Network" "WARN" "connectivity not confirmed"
  fi

  if [[ -f /etc/pacman.conf ]] && grep -Eiq 'cachyos|core|extra' /etc/pacman.conf; then
    print_preflight_check "Pacman config" "OK" "/etc/pacman.conf present"
  else
    print_preflight_check "Pacman config" "WARN" "CachyOS live ISO pacman config not confirmed"
  fi

  if ((${#missing[@]})); then
    print_preflight_check "Required commands" "FAIL" "${missing[*]}"
  else
    print_preflight_check "Required commands" "OK" "all installer commands found"
  fi

  log "Disk inventory"
  print_disks
  log "Stable disk identifiers"
  print_disk_ids

  cat <<EOF

Unsupported-but-possible scenarios are warnings in v1:
  - NVIDIA-specific setup
  - full-disk encryption
  - dual-boot resizing
  - unusual disk topology
  - Secure Boot enabled before installation

Hard stops for --install:
  - not root
  - no interactive terminal
  - not booted in UEFI mode
  - EFI variables unavailable
  - required block/install commands missing
  - no whole disk selected
EOF
}

run_install() {
  require_root
  setup_logging
  trap 'on_exit $?' EXIT
  require_tty
  require_commands awk blkid btrfs cachyos-rate-mirrors efibootmgr findmnt genfstab lsblk mkfs.btrfs mkfs.fat mkswap pacman pacstrap parted partprobe readlink sed swapon udevadm wipefs arch-chroot
  require_uefi
  ensure_tui_backend
  announce_interaction_mode
  tui_msg "CachyOS installer" "This installer performs a destructive fresh install.\n\nIt creates one large Btrfs capacity pool. Extra disks add capacity, not data redundancy. If any pool disk fails, data may be lost.\n\nKeep backups on separate storage."
  select_disks
  collect_swap_policy
  collect_identity
  build_partition_plan
  confirm_destruction
  prepare_live_environment
  wipe_and_partition
  format_filesystems
  create_subvolumes
  mount_target
  install_packages
  copy_pacman_configuration
  write_fstab
  configure_system
  configure_limine
  verify_installation

  log "Installation complete"
  cat <<EOF

Review the verification output above before rebooting.

The full install log is saved at:

  $LOG_FILE

To reboot:

  swapoff -a
  umount -R $TARGET_MOUNT
  reboot

Secure Boot remains disabled by design. Configure it later using:

  installation/post-install-secure-boot.md

EOF
}

main() {
  parse_args "$@"
  case "$MODE" in
    help)
      usage
      ;;
    preflight)
      setup_logging
      trap 'on_exit $?' EXIT
      run_preflight
      ;;
    install)
      run_install
      ;;
    self-test)
      self_test
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac
}

main "$@"

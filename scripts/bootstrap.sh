#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/JimStroomberg/Cachyos-install"
RAW_BASE="https://raw.githubusercontent.com/JimStroomberg/Cachyos-install/main"
INSTALLER_REL="scripts/install-cachyos.sh"
WORK_DIR=""

log() {
  printf '\n==> %s\n' "$*" >&2
}

warn() {
  printf '\nWARNING: %s\n' "$*" >&2
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    bash "$@"
  else
    sudo bash "$@"
  fi
}

run_command_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

prepare_live_repositories() {
  if command -v timedatectl >/dev/null 2>&1; then
    run_command_as_root timedatectl set-ntp true || warn "Could not enable NTP in the live environment."
  fi

  if command -v cachyos-rate-mirrors >/dev/null 2>&1; then
    log "Configuring CachyOS mirrors in the live environment"
    run_command_as_root cachyos-rate-mirrors || warn "Mirror ranking failed; pacman may still be unable to install dialog."
  else
    warn "cachyos-rate-mirrors is unavailable; pacman may not have repository servers configured."
  fi
}

ensure_dialog() {
  if command -v dialog >/dev/null 2>&1; then
    log "dialog is already available for guided menus"
    return
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman is unavailable; guided menus may fall back to plain numbered prompts."
    return
  fi

  prepare_live_repositories

  log "Installing dialog in the temporary live environment"
  if ! run_command_as_root pacman -Sy --needed --noconfirm dialog; then
    warn "Could not install dialog; the installer will fall back if needed."
  fi
}

local_installer() {
  local script_dir repo_dir candidate
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 0
  repo_dir="$(cd -- "$script_dir/.." && pwd)" || return 0
  candidate="$repo_dir/$INSTALLER_REL"
  if [[ -f "$candidate" ]]; then
    printf '%s' "$candidate"
  fi
}

download_installer() {
  WORK_DIR="$(mktemp -d /tmp/cachyos-installer.XXXXXX)"

  if command -v git >/dev/null 2>&1; then
    log "Downloading installer repository with git"
    if git clone --depth 1 "$REPO_URL" "$WORK_DIR/repo"; then
      printf '%s' "$WORK_DIR/repo/$INSTALLER_REL"
      return
    fi
    warn "git clone failed; falling back to direct script download."
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required when git is unavailable."
  log "Downloading installer script directly"
  mkdir -p "$WORK_DIR/scripts"
  curl -fsSL "$RAW_BASE/$INSTALLER_REL" -o "$WORK_DIR/$INSTALLER_REL"
  chmod +x "$WORK_DIR/$INSTALLER_REL"
  printf '%s' "$WORK_DIR/$INSTALLER_REL"
}

main() {
  local installer

  cat <<EOF
CachyOS beginner-friendly gaming installer

Project:
  $REPO_URL

This bootstrap runs a non-destructive preflight report first. If the report
looks reasonable, it launches the guided destructive installer.
EOF

  installer="$(local_installer)"
  if [[ -z "$installer" ]]; then
    installer="$(download_installer)"
  fi

  [[ -f "$installer" ]] || die "Installer script was not found: $installer"

  ensure_dialog

  log "Running preflight report"
  run_as_root "$installer" --preflight

  printf '\nReview the preflight report above.\n' >&2
  printf 'Press Enter to open the guided installer, or Ctrl+C to stop. ' >&2
  read -r _ < /dev/tty

  log "Launching guided installer"
  run_as_root "$installer" --install
}

main "$@"

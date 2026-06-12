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

  log "Running preflight report"
  run_as_root "$installer" --preflight

  printf '\nReview the preflight report above.\n' >&2
  printf 'Press Enter to open the guided installer, or Ctrl+C to stop. ' >&2
  read -r _ < /dev/tty

  log "Launching guided installer"
  run_as_root "$installer" --install
}

main "$@"

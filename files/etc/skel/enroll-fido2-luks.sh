#!/usr/bin/env bash
# Configure LUKS decryption using YubiKey FIDO2 (systemd-cryptenroll)
#
# - Auto-detects root LUKS device via /sysroot (composefs-safe)
# - Enrolls FIDO2 on that LUKS block device
# - Updates /etc/crypttab (even with multiple entries) to include fido2-device=auto
# - Enables rpm-ostree initramfs regeneration
#
# Usage:
#   sudo ./enroll-fido2-luks.sh
#   sudo ./enroll-fido2-luks.sh --dry-run
#
# IMPORTANT: Keep at least one passphrase slot as a fallback.

set -euo pipefail

# Status print helpers
info()  { echo -e "\e[1;34m[INFO]\e[0m $*" >&2; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m $*" >&2; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; }

usage() {
  cat <<'EOF'
Usage:
  enroll-fido2-luks.sh [--dry-run] [--yes]

Options:
  --dry-run   Print what would be done (no enrollment, no file changes)
  --yes       Do not prompt for confirmation
  -h, --help  Show this help
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "Please run as root (sudo $0)."
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { error "Missing required command: $cmd"; exit 1; }
}

DRY_RUN=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --yes)     AUTO_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

# Strip findmnt bracket subpaths:
#   /dev/dm-0[/root] -> /dev/dm-0
strip_bracket_subpath() {
  # remove '[' and everything after it
  sed 's/\[.*$//'
}

detect_root_luks_device() {
  local sysroot_src_raw sysroot_src sysroot_real mapper_name luks_dev

  sysroot_src_raw="$(findmnt -n -o SOURCE /sysroot 2>/dev/null || true)"
  [[ -n "$sysroot_src_raw" ]] || { error "Unable to detect /sysroot SOURCE (is /sysroot mounted?)"; return 1; }

  # Fix: findmnt may return /dev/dm-0[/root] — strip bracket subpath
  sysroot_src="$(echo "$sysroot_src_raw" | strip_bracket_subpath)"
  sysroot_src="$(echo -n "$sysroot_src" | awk '{$1=$1; print}')"  # trim whitespace

  info "Sysroot SOURCE (raw): $sysroot_src_raw"
  info "Sysroot SOURCE (device): $sysroot_src"

  sysroot_real="$(readlink -f "$sysroot_src" 2>/dev/null || echo "$sysroot_src")"
  info "Sysroot SOURCE (resolved): $sysroot_real"

  if [[ "$sysroot_real" == /dev/mapper/* ]]; then
    mapper_name="${sysroot_real#/dev/mapper/}"
  elif [[ "$sysroot_real" == /dev/dm-* ]]; then
    mapper_name="$(dmsetup info -C --noheadings -o name "$sysroot_real" 2>/dev/null | awk '{print $1}' || true)"
  else
    mapper_name="$sysroot_real"
  fi

  [[ -n "$mapper_name" ]] || { error "Unable to determine mapper name from $sysroot_real"; return 1; }
  info "Root mapper name: $mapper_name"

  luks_dev="$(cryptsetup status "$mapper_name" 2>/dev/null | awk '/^[[:space:]]*device:/ {print $2; exit}')"
  [[ -n "$luks_dev" ]] || { error "cryptsetup status did not reveal backing device for $mapper_name"; return 1; }

  info "Backing device from cryptsetup: $luks_dev"

  if [[ ! -b "$luks_dev" ]]; then
    error "Detected backing device is not a block device: $luks_dev"
    return 1
  fi

  if ! cryptsetup isLuks "$luks_dev" >/dev/null 2>&1; then
    error "Detected backing device is not LUKS: $luks_dev"
    return 1
  fi

  echo "$luks_dev"
}

update_crypttab_all_entries() {
  local crypttab="/etc/crypttab"
  local backup="/etc/crypttab.bak.$(date +%s)"

  [[ -f "$crypttab" ]] || { error "/etc/crypttab not found. Manual configuration is required."; return 1; }

  if $DRY_RUN; then
    info "[DRY-RUN] Would back up $crypttab to $backup"
    info "[DRY-RUN] Would ensure fido2-device=auto is present on all active entries"
    return 0
  fi

  cp -a "$crypttab" "$backup"
  info "Backed up /etc/crypttab to $backup"

  awk '
    BEGIN { OFS="\t" }
    /^[[:space:]]*#/ { print; next }
    NF==0 { print; next }
    {
      # Fields: name device password options
      if (NF < 4) { print $0, "fido2-device=auto"; next }
      if ($4 ~ /(^|,)fido2-device=/) { print; next }
      $4 = $4 ",fido2-device=auto"
      print
    }
  ' "$backup" > "$crypttab"

  info "Updated /etc/crypttab (all active entries)."
}

enable_initramfs_regen() {
  if $DRY_RUN; then
    info "[DRY-RUN] Would run: rpm-ostree initramfs --enable"
    return 0
  fi
  rpm-ostree initramfs --enable
}

enroll_fido2() {
  local luks_device="$1"

  if $DRY_RUN; then
    info "[DRY-RUN] Would enroll FIDO2 on: $luks_device"
    info "[DRY-RUN] Command: systemd-cryptenroll --fido2-device=auto --fido2-with-user-presence=yes $luks_device"
    return 0
  fi

  info "Enrolling your YubiKey (FIDO2) with $luks_device..."
  systemd-cryptenroll \
    --fido2-device=auto \
    --fido2-with-user-presence=yes \
    "$luks_device"
}

main() {
  require_root
  require_cmd findmnt
  require_cmd readlink
  require_cmd dmsetup
  require_cmd cryptsetup
  require_cmd systemd-cryptenroll
  require_cmd rpm-ostree
  require_cmd awk
  require_cmd cp
  require_cmd date
  require_cmd lsblk
  require_cmd sed

  echo -e "\e[1;36mThis script will:\e[0m
  - Auto-detect your root LUKS device (composefs-safe via /sysroot)
  - Enroll your YubiKey (FIDO2) using systemd-cryptenroll
  - Update /etc/crypttab (even with multiple entries) to include fido2-device=auto
  - Enable rpm-ostree initramfs regeneration
  - Prompt for reboot

\e[1;33mImportant:\e[0m Keep at least one passphrase slot as a fallback."

  echo -e "\e[1;31m
████████████████████████████████████████████████████████████
⚠️  WARNING – POTENTIAL DATA LOSS / BOOT FAILURE RISK ⚠️
████████████████████████████████████████████████████████████

This script modifies LUKS metadata and early-boot configuration.

Incorrect use MAY RESULT IN:
  • An unbootable system
  • Loss of access to encrypted data
  • Requirement to recover using a LUKS passphrase or backup

BEFORE PROCEEDING, ENSURE:
  • You KNOW your existing LUKS passphrase
  • You have tested LUKS unlock manually
  • Your YubiKey FIDO2 PIN is set
  • You understand this is a SYSTEM-LEVEL change

THIS SCRIPT MAKES NO GUARANTEES.
YOU PROCEED ENTIRELY AT YOUR OWN RISK.

████████████████████████████████████████████████████████████
\e[0m"

  if $DRY_RUN; then
    warn "DRY-RUN mode enabled: no changes will be made."
  fi

  if ! $AUTO_YES; then
    echo -e "\n\e[1;33mDo you want to proceed? (y/N)\e[0m"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "\e[1;31mAborted by user.\e[0m"
      exit 1
    fi
  fi

  info "Detecting root LUKS device..."
  local luks_device
  luks_device="$(detect_root_luks_device)" || { error "Auto-detect failed. Not making changes."; exit 1; }

  info "Detected root LUKS device: $luks_device"

  info "Current mapping chain (lsblk):"
  lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT,PKNAME | sed 's/^/  /'

  enroll_fido2 "$luks_device"
  update_crypttab_all_entries
  enable_initramfs_regen

  echo ""
  info "Done."
  if $DRY_RUN; then
    warn "Dry-run complete. No changes were applied."
    exit 0
  fi

  info "Reboot required to test FIDO2 unlock at boot."
  read -rp $'\e[1;33mDo you want to reboot now? (y/N): \e[0m' reboot_now
  if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
    info "Rebooting..."
    reboot
  else
    info "Reboot later to test: with YubiKey inserted (touch), and without (fallback passphrase)."
  fi
}

main "$@"

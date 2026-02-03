#!/usr/bin/env bash
# Configure LUKS decryption using YubiKey FIDO2 (systemd-cryptenroll)
#
# - Auto-detects root LUKS device via /sysroot (composefs-safe)
# - Enrolls FIDO2 on ALL LUKS block devices (detected via lsblk FSTYPE=crypto_LUKS)
#   - Skips devices that already have a FIDO2 token enrolled
# - Updates /etc/crypttab (even with multiple entries) to include fido2-device=auto
# - Enables rpm-ostree initramfs regeneration
#
# Usage:
#   sudo ./enroll-fido2-luks.sh
#   sudo ./enroll-fido2-luks.sh --dry-run
#
# IMPORTANT: Keep at least one passphrase slot as a fallback.

set -euo pipefail

# Status print helpers (stderr so stdout can be used for return values)
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
  sed 's/\[.*$//'
}

detect_root_luks_device() {
  local sysroot_src_raw sysroot_src sysroot_real mapper_name luks_dev

  sysroot_src_raw="$(findmnt -n -o SOURCE /sysroot 2>/dev/null || true)"
  [[ -n "$sysroot_src_raw" ]] || { error "Unable to detect /sysroot SOURCE (is /sysroot mounted?)"; return 1; }

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

  [[ -b "$luks_dev" ]] || { error "Detected backing device is not a block device: $luks_dev"; return 1; }
  cryptsetup isLuks "$luks_dev" >/dev/null 2>&1 || { error "Detected backing device is not LUKS: $luks_dev"; return 1; }

  echo "$luks_dev"
}

list_all_luks_devices() {
  # List all block devices whose filesystem type is crypto_LUKS.
  # Output format: /dev/<name> per line
  lsblk -rpn -o NAME,FSTYPE 2>/dev/null \
    | awk '$2 == "crypto_LUKS" { print $1 }'
}

device_has_fido2_enrolled() {
  local luks_device="$1"
  # systemd-cryptenroll --dump prints token info; we look for "fido2" in a conservative way.
  # If dump fails, treat as not-enrolled (caller can decide to skip/error).
  systemd-cryptenroll --dump "$luks_device" 2>/dev/null | grep -qiE '\bfido2\b'
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

enroll_fido2_all_luks_devices() {
  local root_luks="$1"
  local devices=()
  local d

  # Build list (preserve order): root first (if present), then others
  while IFS= read -r d; do
    [[ -n "$d" ]] && devices+=("$d")
  done < <(list_all_luks_devices)

  if [[ "${#devices[@]}" -eq 0 ]]; then
    warn "No crypto_LUKS devices found via lsblk. Nothing to enroll."
    return 0
  fi

  info "Discovered LUKS devices:"
  for d in "${devices[@]}"; do
    info "  - $d"
  done

  # Ensure root goes first if it is in the list
  if [[ -n "$root_luks" ]]; then
    local reordered=()
    local seen_root=false
    for d in "${devices[@]}"; do
      if [[ "$d" == "$root_luks" ]]; then
        seen_root=true
      fi
    done

    if $seen_root; then
      reordered+=("$root_luks")
      for d in "${devices[@]}"; do
        [[ "$d" == "$root_luks" ]] && continue
        reordered+=("$d")
      done
      devices=("${reordered[@]}")
    else
      warn "Root LUKS device ($root_luks) was not found in lsblk crypto_LUKS list. Proceeding with discovered devices only."
    fi
  fi

  for d in "${devices[@]}"; do
    if [[ ! -b "$d" ]]; then
      warn "Skipping (not a block device): $d"
      continue
    fi
    if ! cryptsetup isLuks "$d" >/dev/null 2>&1; then
      warn "Skipping (not LUKS): $d"
      continue
    fi

    if device_has_fido2_enrolled "$d"; then
      info "Skipping (FIDO2 already enrolled): $d"
      continue
    fi

    enroll_fido2 "$d"
  done
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

  # rpm-ostree returns a non-zero exit code if it's already enabled.
  # Treat that case as success.
  local out
  if out="$(rpm-ostree initramfs --enable 2>&1)"; then
    info "Initramfs regeneration enabled."
    return 0
  fi

  if echo "$out" | grep -qi "already enabled"; then
    info "Initramfs regeneration already enabled; continuing."
    return 0
  fi

  # Any other failure is real.
  error "Failed to enable initramfs regeneration: $out"
  return 1
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
  require_cmd grep

  echo -e "\e[1;36mThis script will:\e[0m
  - Auto-detect your root LUKS device (composefs-safe via /sysroot)
  - Enroll your YubiKey (FIDO2) on ALL detected LUKS devices (lsblk FSTYPE=crypto_LUKS)
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
  local root_luks_device
  root_luks_device="$(detect_root_luks_device)" || { error "Auto-detect failed. Not making changes."; exit 1; }
  info "Detected root LUKS device: $root_luks_device"

  info "Current mapping chain (lsblk):"
  lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT,PKNAME | sed 's/^/  /'

  # Enroll FIDO2 for all LUKS devices (root first)
  enroll_fido2_all_luks_devices "$root_luks_device"

  # Ensure crypttab options are present for all active entries
  update_crypttab_all_entries

  # Enable initramfs regeneration for early boot unlock support
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
    info "Reboot later to test: with YubiKey inserted (touch/PIN as required), and without (fallback passphrase)."
  fi
}

main "$@"

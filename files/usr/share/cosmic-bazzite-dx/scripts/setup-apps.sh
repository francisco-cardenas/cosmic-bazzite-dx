#!/usr/bin/env bash
# Optional Flatpak application installs
# Can be run standalone: bash ~/setup-apps.sh

set -uo pipefail

# --- Output helpers ---
OK="\e[1;32m[ OK ]\e[0m"
INFO="\e[1;34m[ INFO ]\e[0m"
WARN="\e[1;33m[ WARN ]\e[0m"
ERROR="\e[1;31m[ ERROR ]\e[0m"

log() {
  local level="$1"; shift
  echo -e "${!level} $*"
}

run_cmd() {
  local cmd="$1"
  log INFO "Running: $cmd"
  if eval "$cmd"; then
    log OK "$cmd completed successfully"
  else
    log ERROR "$cmd failed"
  fi
}

# --- Proton Pass CLI ---
install_proton_pass_cli() {
  echo
  log INFO "Proton Pass CLI:"
  echo "   Installs via: curl -fsSL https://proton.me/download/pass-cli/install.sh | bash"
  log WARN "This executes a remote script directly. Only proceed if you trust the source."
  echo

  if ugum confirm "Install Proton Pass CLI? (curl | bash from proton.me)"; then
    curl -fsSL https://proton.me/download/pass-cli/install.sh | bash \
      && log OK "Proton Pass CLI installed." \
      || log ERROR "Proton Pass CLI install failed."
  else
    log WARN "Skipped Proton Pass CLI."
  fi
}

# --- Flatpak installs ---
install_extra_packages() {
  log INFO "Optional Flatpak applications:"
  echo "   1) Spotify"
  echo "   2) Obsidian"
  echo "   3) Brave Browser"
  echo "   4) Headlamp (Kubernetes dashboard)"
  echo "   5) Synology Drive"
  echo "   6) Install ALL"
  echo "   7) Skip"
  echo

  CHOICE=$(ugum choose "Spotify" "Obsidian" "Brave Browser" "Headlamp" "Synology Drive" "Install ALL" "Skip")

  case "$CHOICE" in
    "Spotify")
      run_cmd "flatpak install -y flathub com.spotify.Client"
      ;;
    "Obsidian")
      run_cmd "flatpak install -y flathub md.obsidian.Obsidian"
      ;;
    "Brave Browser")
      run_cmd "flatpak install -y flathub com.brave.Browser"
      ;;
    "Headlamp")
      run_cmd "flatpak install -y flathub io.kinvolk.Headlamp"
      ;;
    "Synology Drive")
      run_cmd "flatpak install -y flathub com.synology.SynologyDrive"
      ;;
    "Install ALL")
      run_cmd "flatpak install -y flathub com.spotify.Client"
      run_cmd "flatpak install -y flathub md.obsidian.Obsidian"
      run_cmd "flatpak install -y flathub com.brave.Browser"
      run_cmd "flatpak install -y flathub io.kinvolk.Headlamp"
      run_cmd "flatpak install -y flathub com.synology.SynologyDrive"
      ;;
    "Skip"|*)
      log WARN "Skipped optional app installs."
      ;;
  esac
}

main() {
  echo
  echo "======================================"
  echo "   Optional Application Installs"
  echo "======================================"
  echo

  install_extra_packages
  install_proton_pass_cli

  echo
  log OK "Application setup complete."
  exit 0
}

main "$@"

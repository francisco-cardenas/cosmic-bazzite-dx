#!/usr/bin/env bash
# User post-install automation script (interactive)

set -euo pipefail

# --- Colorized output ---
OK="\e[1;32m[ OK ]\e[0m"
INFO="\e[1;34m[ INFO ]\e[0m"
WARN="\e[1;33m[ WARN ]\e[0m"
ERROR="\e[1;31m[ ERROR ]\e[0m"

log() {
	local level="$1"; shift
	echo -e "${!level} $*"
}

# --- Helpers ---
run_cmd() {
	local cmd="$1"
  log INFO "Running: $cmd"
  if eval "$cmd"; then
    log OK "$cmd completed successfully"
  else
    log ERROR "$cmd failed"
  fi
}

# --- Flatpak package install --
install_extra_packages() {
  echo
  echo "======================================"
  echo -e "${INFO} Extra Packages"
  echo "======================================"
  echo
  echo "Optional Flatpak installs:"
  echo "  1) Spotify"
  echo "  2) Obsidian"
  echo "  3) Standard Notes"
  echo "  4) Brave Browser"
  echo "  5) Install ALL (Spotify + Obsidian + Standard Notes + Brave)"
  echo "  6) Skip"
  echo

  read -rp "Select an option (1/2/3/4/5/6): " pkg_choice

  case "${pkg_choice}" in
    1)
      log INFO "Installing Spotify..."
      run_cmd "flatpak install -y flathub com.spotify.Client"
      ;;
    2)
      log INFO "Installing Obsidian..."
      run_cmd "flatpak install -y flathub md.obsidian.Obsidian"
      ;;
    3)
      log INFO "Installing Standard Notes..."
      run_cmd "flatpak install -y flathub org.standardnotes.standardnotes"
      ;;
    4)
      log INFO "Installing Brave Browser..."
      run_cmd "flatpak install -y flathub com.brave.Browser"
      ;;
    5)
      log INFO "Installing ALL extra packages..."
      run_cmd "flatpak install -y flathub com.spotify.Client"
      run_cmd "flatpak install -y flathub md.obsidian.Obsidian"
      run_cmd "flatpak install -y flathub org.standardnotes.standardnotes"
      run_cmd "flatpak install -y flathub com.brave.Browser"
      ;;
    6)
      log WARN "Skipped extra package installs."
      ;;
    *)
      log WARN "Invalid selection — skipping extra packages."
      ;;
  esac
}

# --- Final messages --
print_important_notes() {
  echo
  echo "======================================"
  echo -e "${INFO} Important Notes"
  echo "======================================"
  echo

  echo -e "${INFO} If you plan to use ZSH on Bazzite:"
  echo " - The official documentation recommends *NOT* changing your default login shell."
  echo " - Instead, configure your terminal to launch ZSH through a profile."
  echo
  echo "   See Best Shell Practices:"
  echo "   https://docs.bazzite.gg/Advanced/Best_Shell_Practices/"
  echo

  echo -e "${INFO} Why?"
  echo " - Changing your system login shell may break certain Bazzite features."
  echo " - It may cause issues during rpm-ostree upgrades."
  echo " - It bypasses the intended initialization path for Bazzite environments."
  echo
  echo -e "${OK} Recommended:"
  echo "   Keep the system default shell (usually bash),"
  echo "   and configure ZSH as a terminal-launch profile instead."
  echo
}

# --- Detect if system uses LUKS ---
is_luks_enabled() {
  lsblk -no TYPE | grep -q crypt
}

main() {
  clear
  echo "======================================"
  echo "   Bazzite User Postinstall Setup"
  echo "======================================"
  echo

  # --- LUKS: TPM Unlock Setup ---
  if is_luks_enabled; then
    log INFO "LUKS encryption detected."
    read -rp "Set up TPM unlock for LUKS? (y/n): " choice
    case "${choice,,}" in
      y|yes)
        run_cmd "ujust setup-luks-tpm-unlock"
        ;;
      n|no)
        log WARN "Skipped TPM unlock setup."
        ;;
      *)
        log WARN "Invalid input, skipping TPM unlock setup."
        ;;
    esac
  else
    log INFO "LUKS not detected; skipping TPM unlock setup."
  fi

  echo

  # --- Bazzite CLI ---
  log INFO "Bazzite CLI provides enhanced command-line tools:"
  echo " - atuin, direnv, eza, fd, fzf, ripgrep, tealdeer,"
  echo " - ugrep, yq, zoxide, and more"
  echo

  read -rp "Enable Bazzite CLI experience? (y/n): " cli_choice
  case "${cli_choice,,}" in
    y|yes)
      run_cmd "ujust bazzite-cli"
      ;;
    n|no)
      log WARN "Skipped Bazzite CLI installation."
      ;;
    *)
      log WARN "Invalid input, skipping Bazzite CLI installation."
      ;;
  esac

  echo

  # --- Docker Fix (docker group + usermod) ---
  log INFO "Docker Fix:"
  echo " - Create docker group (if missing)"
  echo " - Add your user to docker group"
  echo
  read -rp "Apply Docker fix so Docker can run without sudo? (y/n): " docker_choice

  case "${docker_choice,,}" in
    y|yes)
      if ! getent group docker >/dev/null; then
        run_cmd "sudo groupadd docker"
      else
        log INFO "Group 'docker' already exists"
      fi

      run_cmd "sudo usermod -aG docker $USER"

      echo
      log WARN "You MUST log out and log back in for this change to take effect."
      ;;
    n|no)
      log WARN "Skipped Docker group fix."
      ;;
    *)
      log WARN "Invalid input, skipping Docker fix."
      ;;
  esac

  echo
  log OK "User postinstall completed."
  echo
 
 	# --- Install extra packages ---
  install_extra_packages

	# --- Print final message ---
  print_important_notes
  echo -e "${OK} Postinstall script complete."
}

main "$@"


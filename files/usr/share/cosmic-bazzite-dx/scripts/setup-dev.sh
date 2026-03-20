#!/usr/bin/env bash
# Developer tools setup: CLI tools + fonts, Docker group fix
# Can be run standalone: bash ~/setup-dev.sh

set -uo pipefail

BREWFILE="/usr/share/cosmic-bazzite-dx/homebrew/bazzite-dx.Brewfile"

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

# --- Bazzite DX tools + fonts ---
setup_brew_packages() {
  if [[ ! -f "$BREWFILE" ]]; then
    log ERROR "Brewfile not found: $BREWFILE"
    return
  fi

  log INFO "Bazzite DX packages (CLI tools + fonts via Homebrew):"
  echo "   atuin, bat, chezmoi, direnv, eza, fd, gh, glab,"
  echo "   ripgrep, shellcheck, starship, tealdeer, trash-cli,"
  echo "   television, ugrep, yq, zoxide"
  echo "   age, cilium-cli, helm, kubectl, sops, stow, talosctl, terraform"
  echo "   + JetBrains Mono Nerd Font"
  echo

  if ugum confirm "Install Bazzite DX packages?"; then
    run_cmd "brew bundle --file \"$BREWFILE\""
  else
    log WARN "Skipped Bazzite DX packages."
  fi
}

# --- Docker group fix ---
setup_docker_group() {
  log INFO "Docker fix:"
  echo "   - Create the docker group (if missing)"
  echo "   - Add your user to the docker group"
  echo

  if ugum confirm "Allow Docker to run without sudo?"; then
    if ! getent group docker >/dev/null; then
      run_cmd "sudo groupadd docker"
    else
      log INFO "Group 'docker' already exists."
    fi
    run_cmd "sudo usermod -aG docker ${USER:?USER is not set}"
    echo
    log WARN "Log out and back in for the group change to take effect."
  else
    log WARN "Skipped Docker group fix."
  fi
}

main() {
  echo
  echo "======================================"
  echo "   Developer Tools Setup"
  echo "======================================"
  echo

  setup_brew_packages
  echo
  setup_docker_group

  echo
  log OK "Developer tools setup complete."
  exit 0
}

main "$@"

#!/usr/bin/env bash
# ZSH setup: Oh My Zsh + plugins
# Can be run standalone: bash ~/setup-zsh.sh

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

# --- Oh My Zsh ---
install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log INFO "Oh My Zsh already installed — skipping."
  else
    log INFO "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended
    log OK "Oh My Zsh installed."
  fi
}

# --- Plugins ---
clone_plugin() {
  local name="$1"
  local url="$2"
  local dest="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${name}"

  if [[ -d "$dest" ]]; then
    log INFO "${name} already installed — skipping."
  else
    log INFO "Cloning ${name}..."
    git clone "$url" "$dest"
    log OK "${name} installed."
  fi
}

install_plugins() {
  clone_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions"
  clone_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git"
}

# --- Main ---
main() {
  echo
  echo "======================================"
  echo "   ZSH Setup"
  echo "======================================"
  echo

  if ! command -v zsh >/dev/null; then
    log ERROR "ZSH is not installed — skipping ZSH setup."
    exit 0
  fi

  if ! command -v curl >/dev/null || ! command -v git >/dev/null; then
    log ERROR "curl and git are required for ZSH setup."
    exit 0
  fi

  log INFO "This will install:"
  echo "   - Oh My Zsh"
  echo "   - zsh-autosuggestions"
  echo "   - zsh-syntax-highlighting"
  echo

  if ugum confirm "Set up Oh My Zsh and plugins?"; then
    install_oh_my_zsh
    echo
    install_plugins
  else
    log WARN "Skipped ZSH setup."
  fi

  echo
  log OK "ZSH setup complete."
  exit 0
}

main "$@"

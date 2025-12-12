#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images.
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Install base tools
dnf5 install -y tmux zsh cups hplip


# Install COSMIC and related components
dnf5 install -y \
    cosmic-edit \
    cosmic-files \
    cosmic-player \
    cosmic-session \
    cosmic-app-library \
    cosmic-applets \
    cosmic-bg \
    cosmic-comp \
    cosmic-config-fedora \
    cosmic-greeter \
    cosmic-icon-theme \
    cosmic-idle \
    cosmic-initial-setup \
    cosmic-launcher \
    cosmic-notifications \
    cosmic-osd \
    cosmic-panel \
    cosmic-randr \
    cosmic-screenshot \
    cosmic-settings \
    cosmic-settings-daemon \
    cosmic-term \
    cosmic-workspaces \
    xdg-desktop-portal-cosmic \
    cosmic-wallpapers

#### Example for enabling a System Unit File
systemctl enable podman.socket

ls /ctx 

### Configure ZSH
install -Dm644 /ctx/files/etc/skel/.zshrc /usr/share/defaults/skel/.zshrc 

### Post install script to $HOME
install -Dm755 /ctx/files/etc/skel/post-install.sh /usr/share/defaults/skel/.post-install.sh

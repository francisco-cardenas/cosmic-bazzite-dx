#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images.
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Install base tools
dnf5 install -y tmux zsh

### Install COSMIC Desktop Environment

# Install COSMIC and related components
dnf5 install -y \
    cosmic-comp \
    cosmic-session \
    cosmic-settings \
    cosmic-launcher \
    cosmic-files \
    cosmic-edit \
    cosmic-term \
    cosmic-panel \
    cosmic-applets \
    cosmic-workspace \
    cosmic-osd \
    cosmic-notifications \
    cosmic-screenshot \
    cosmic-greeter \
    cosmic-bg \
    cosmic-icons \
    cosmic-gtk-theme \
    cosmic-wallpapers \
    cosmic-applibrary

#### Example for enabling a System Unit File
systemctl enable podman.socket


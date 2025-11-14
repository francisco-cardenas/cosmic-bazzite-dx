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
# Install Rawhide repository definitions (kept disabled)
# This does NOT activate the Rawhide repo globally.
dnf5 install -y fedora-repos-rawhide

# Install COSMIC and related components
dnf5 install -y \
    cosmic-desktop-environment \
    cosmic-session \
    cosmic-term \
    cosmic-files \
    cosmic-settings \
    cosmic-app-library \
    --enablerepo=rawhide

# Remove the temporary Rawhide repo after installation
dnf5 -y removerepo rawhide

#### Example for enabling a System Unit File
systemctl enable podman.socket


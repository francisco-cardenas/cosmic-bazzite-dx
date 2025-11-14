#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images.
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Install base tools
dnf5 install -y tmux

### Install COSMIC Desktop Environment
# Add the Fedora Rawhide repo temporarily to access COSMIC packages
dnf5 -y addrepo --from-repofile=https://download.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/

# Install COSMIC and related components
dnf5 install -y \
    cosmic-desktop-environment \
    cosmic-session \
    cosmic-term \
    cosmic-files \
    cosmic-settings \
    cosmic-app-library

# Remove the temporary Rawhide repo after installation
dnf5 -y removerepo rawhide

#### Example for enabling a System Unit File
systemctl enable podman.socket


#!/bin/bash

set -ouex pipefail

### Install base tools
dnf5 install -y tmux zsh cups hplip fido2-tools

### Install COSMIC and related components
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

### Enable system services
systemctl enable podman.socket

### Dracut snippet for initramfs to include fido2 support
install -Dm0644 /ctx/files/etc/dracut.conf.d/fido2.conf /etc/dracut.conf.d/fido2.conf

### System commands
mkdir -p "$(readlink -f /usr/local)/bin"
install -m755 /ctx/files/usr/local/bin/enroll-fido2-luks /usr/local/bin/enroll-fido2-luks

### cosmic-bazzite-dx shared resources
install -Dm644 /ctx/files/usr/share/cosmic-bazzite-dx/homebrew/bazzite-dx.Brewfile \
    /usr/share/cosmic-bazzite-dx/homebrew/bazzite-dx.Brewfile

### cosmic-bazzite-dx setup scripts
install -Dm755 /ctx/files/usr/share/cosmic-bazzite-dx/scripts/setup-dev.sh \
    /usr/share/cosmic-bazzite-dx/scripts/setup-dev.sh
install -Dm755 /ctx/files/usr/share/cosmic-bazzite-dx/scripts/setup-zsh.sh \
    /usr/share/cosmic-bazzite-dx/scripts/setup-zsh.sh
install -Dm755 /ctx/files/usr/share/cosmic-bazzite-dx/scripts/setup-apps.sh \
    /usr/share/cosmic-bazzite-dx/scripts/setup-apps.sh

### ujust recipes
install -Dm644 /ctx/files/usr/share/ublue-os/just/96-cosmic-bazzite-dx-security.just \
    /usr/share/ublue-os/just/96-cosmic-bazzite-dx-security.just
install -Dm644 /ctx/files/usr/share/ublue-os/just/97-cosmic-bazzite-dx-setup.just \
    /usr/share/ublue-os/just/97-cosmic-bazzite-dx-setup.just

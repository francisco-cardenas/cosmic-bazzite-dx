# cosmic-bazzite-dx

A custom immutable OS image built on [Bazzite DX](https://bazzite.gg) that adds the [COSMIC desktop environment](https://system76.com/cosmic), developer tooling, and security-focused setup automation.

Built with [Universal Blue's image template](https://github.com/ublue-os/image-template) and distributed via GitHub Container Registry.

## What's Included

### COSMIC Desktop Environment
Full COSMIC DE suite including compositor, greeter, panel, launcher, workspaces, settings, notifications, and COSMIC apps (editor, file manager, media player).

### Developer Tools (via Homebrew)
Installed with `ujust setup-dev`:

**CLI Tools**
- `atuin` — shell history sync
- `bat` — cat with syntax highlighting
- `chezmoi` — dotfile manager
- `direnv` — directory-scoped env vars
- `eza` — modern ls replacement
- `fd` — fast find replacement
- `gh` / `glab` — GitHub and GitLab CLIs
- `ripgrep` — fast grep replacement
- `shellcheck` — shell script linter
- `starship` — cross-shell prompt
- `tealdeer` — fast tldr pages
- `television` — fuzzy file finder
- `trash-cli` — safe rm replacement
- `ugrep` — feature-rich grep
- `yq` — YAML/JSON processor
- `zoxide` — smarter cd

**Infrastructure / Ops**
- `age` + `sops` — secrets encryption
- `cilium-cli` — Cilium CNI management
- `helm` — Kubernetes package manager
- `kubectl` — Kubernetes CLI
- `talosctl` — Talos Linux management
- `terraform` — infrastructure as code
- `stow` — symlink dotfile manager

**Fonts**
- JetBrains Mono Nerd Font

### System Packages (via dnf)
- `zsh`, `tmux`
- `cups`, `hplip` — printing support
- `fido2-tools` — FIDO2/YubiKey support
- Full COSMIC DE packages

### Security
- FIDO2 dracut module for hardware key unlock at boot
- `enroll-fido2-luks` system command for YubiKey LUKS enrollment
- TPM unlock support via `ujust setup-security`

### Services
- `podman.socket` enabled for rootless container workflows

---

## ujust Commands

All commands are available via `ujust` after installing the image.

### cosmic-bazzite-dx: Security

| Command | Description |
|---|---|
| `ujust setup-security` | LUKS TPM unlock setup + FIDO2 enrollment reminder |
| `ujust enroll-fido2-luks` | Enroll YubiKey (FIDO2) for LUKS unlock |
| `ujust enroll-fido2-luks --dry-run` | Preview FIDO2 enrollment without making changes |

### cosmic-bazzite-dx: Setup

| Command | Description |
|---|---|
| `ujust setup-dev` | Install developer tools and fonts via Homebrew + Docker group fix |
| `ujust setup-zsh` | Set up ZSH with Oh My Zsh and plugins |
| `ujust setup-apps` | Install optional applications via Flatpak |

### Optional Applications (`ujust setup-apps`)
- Spotify
- Obsidian
- Brave Browser
- Headlamp (Kubernetes dashboard)
- Synology Drive
- Proton Pass CLI

---

## Installation

### Rebase to this image

```bash
# Rebase to the signed image
ujust rebase-helper ghcr.io/francisco-cardenas/cosmic-bazzite-dx:latest
```

### After first boot

Run the setup commands to configure your environment:

```bash
ujust setup-security   # LUKS/TPM setup (if applicable)
ujust setup-dev        # CLI tools, fonts, Docker group
ujust setup-zsh        # Oh My Zsh + plugins
ujust setup-apps       # Optional Flatpak apps
```

---

## Building Locally

Requires [podman](https://podman.io) and [just](https://github.com/casey/just).

```bash
git clone https://github.com/francisco-cardenas/cosmic-bazzite-dx
cd cosmic-bazzite-dx
just build
```

### Build a disk image (ISO/qcow2)

```bash
just build-qcow2
```

---

## Verification

Images are signed with [cosign](https://github.com/sigstore/cosign). Verify with:

```bash
cosign verify ghcr.io/francisco-cardenas/cosmic-bazzite-dx \
  --certificate-identity-regexp="https://github.com/francisco-cardenas/cosmic-bazzite-dx" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

---

## Base Image

Built from `ghcr.io/ublue-os/bazzite-dx-gnome:stable`. See the [Universal Blue project](https://universal-blue.org) for more details on the base image.

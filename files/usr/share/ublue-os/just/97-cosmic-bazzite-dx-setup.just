# vim: set ft=make :

# Install developer tools and fonts via Homebrew (CLI tools + infra/ops)
[group('cosmic-bazzite-dx')]
setup-dev:
    #!/usr/bin/bash
    bash /usr/share/cosmic-bazzite-dx/scripts/setup-dev.sh

# Set up ZSH with Oh My Zsh and plugins
[group('cosmic-bazzite-dx')]
setup-zsh:
    #!/usr/bin/bash
    bash /usr/share/cosmic-bazzite-dx/scripts/setup-zsh.sh

# Install optional applications via Flatpak
[group('cosmic-bazzite-dx')]
setup-apps:
    #!/usr/bin/bash
    bash /usr/share/cosmic-bazzite-dx/scripts/setup-apps.sh

# Switch display manager between gdm and cosmic-greeter
[group('cosmic-bazzite-dx')]
switch-greeter *args:
    #!/usr/bin/bash
    sudo switch-greeter {{ args }}

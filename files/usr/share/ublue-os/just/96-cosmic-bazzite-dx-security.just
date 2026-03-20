# vim: set ft=make :

# Set up security: LUKS TPM unlock + FIDO2 enrollment reminder
[group('cosmic-bazzite-dx')]
setup-security:
    #!/usr/bin/bash
    set -uo pipefail
    source /usr/lib/ujust/ujust.sh

    echo
    echo "======================================"
    echo "   Security Setup"
    echo "======================================"
    echo

    if lsblk -no TYPE | grep -q crypt; then
        echo "LUKS encryption detected."
        echo
        if ugum confirm "Set up TPM unlock for LUKS?"; then
            ujust setup-luks-tpm-unlock
        else
            echo "Skipped TPM unlock setup."
        fi
    else
        echo "LUKS not detected — skipping TPM unlock setup."
    fi

    echo
    echo "YubiKey FIDO2 enrollment is available as a separate step."
    echo "Run when ready:"
    echo
    echo "   ujust enroll-fido2-luks"
    echo "   ujust enroll-fido2-luks --dry-run   (preview first)"
    echo

# Enroll YubiKey (FIDO2) for LUKS unlock
[group('cosmic-bazzite-dx')]
enroll-fido2-luks ACTION="":
    #!/usr/bin/bash
    if [[ "{{ ACTION }}" == "--dry-run" ]]; then
        sudo enroll-fido2-luks --dry-run
    else
        sudo enroll-fido2-luks
    fi

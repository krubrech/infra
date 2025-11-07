#!/usr/bin/env bash
# Generic script to install NixOS on a host using nixos-anywhere
# Converts existing OS -> NixOS in-place
#
# Usage: ./infect.sh <hostname> [user]

set -e

# Function to get host IP address
get_host_ip() {
    case "$1" in
        rabbit)
            echo "91.98.95.99"
            ;;
        mole)
            echo "192.168.1.219"
            ;;
        *)
            echo "Unknown host: $1" >&2
            echo "Available hosts: rabbit, mole" >&2
            exit 1
            ;;
    esac
}

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <hostname> [user]"
    echo ""
    echo "Arguments:"
    echo "  hostname  - Name of the host to infect (rabbit, mole)"
    echo "  user      - SSH user (default: root)"
    echo ""
    echo "Examples:"
    echo "  $0 mole pi"
    echo "  $0 rabbit root"
    echo ""
    echo "WARNING: This will wipe the target system and install NixOS!"
    exit 1
fi

HOSTNAME="$1"
USER="${2:-root}"
IP=$(get_host_ip "$HOSTNAME")
HOST="$USER@$IP"

echo "=================================================="
echo "  NixOS Installation via nixos-anywhere"
echo "=================================================="
echo "Target:   $HOSTNAME ($IP)"
echo "SSH User: $USER"
echo "Config:   .#$HOSTNAME"
echo ""
echo "WARNING: This will wipe $HOSTNAME and install NixOS!"
echo "         All existing data will be lost!"
echo "=================================================="
echo ""

read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Running nixos-anywhere to install NixOS on $HOSTNAME..."
echo ""

nix run github:nix-community/nixos-anywhere -- --flake ".#$HOSTNAME" "$HOST"

echo ""
echo "=================================================="
echo "  Installation complete!"
echo "=================================================="
echo ""
echo "The system should reboot automatically into NixOS."
echo ""
echo "Next steps:"
echo "  1. Wait for the system to reboot"
echo "  2. Test SSH access: ssh root@$IP"
echo "  3. Get the host's age key for sops:"
echo "     ssh root@$IP 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'"
echo "  4. Add the age key to .sops.yaml"
echo "  5. Create secrets in secrets/secrets.yaml (passwords, etc.)"
echo "  6. Deploy updates: ./deploy.sh $HOSTNAME"
echo ""

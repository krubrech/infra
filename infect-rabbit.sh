#!/usr/bin/env bash
# Script to install NixOS on rabbit using nixos-infect
# Converts Ubuntu 24.04 -> NixOS 25.05 in-place

set -e

HOST="root@91.98.95.99"

echo "Installing NixOS on $HOST using nixos-infect..."
echo "WARNING: This will convert the system to NixOS!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "Running nixos-infect with channel 25.05..."
ssh "$HOST" "curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIXOS_CHANNEL=nixos-25.05 bash -x"

echo "Installation complete! The system should reboot automatically."
echo "After reboot, you can deploy your config with: ./deploy-rabbit.sh"

#!/usr/bin/env bash
# Script to install NixOS on rabbit using nixos-anywhere
# Converts Ubuntu 24.04 -> NixOS 25.05 in-place

set -e

HOST="root@91.98.95.99"

echo "Installing NixOS on $HOST using nixos-anywhere..."
echo "WARNING: This will wipe the system and install NixOS!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "Running nixos-anywhere to install NixOS 25.05..."
nix run github:nix-community/nixos-anywhere -- --flake .#rabbit "$HOST"

echo "Installation complete! The system should reboot automatically."
echo "After reboot, you can deploy your config with: ./deploy-rabbit.sh"

#!/usr/bin/env bash
# Post-install script to configure sops for rabbit
# Run this after nixos-anywhere has installed NixOS on rabbit

set -e

HOST="root@91.98.95.99"
SOPS_YAML="secrets/.sops.yaml"

echo "Fetching SSH host key from $HOST..."

# Fetch the SSH host public key and convert to age format
AGE_KEY=$(ssh "$HOST" "cat /etc/ssh/ssh_host_ed25519_key.pub" | nix shell nixpkgs#ssh-to-age -c ssh-to-age)

if [ -z "$AGE_KEY" ]; then
    echo "Error: Failed to fetch or convert host key"
    exit 1
fi

echo "Rabbit host age key: $AGE_KEY"

# Update .sops.yaml with the actual key
echo "Updating $SOPS_YAML..."
sed -i "s/PLACEHOLDER_RABBIT_HOST_KEY/$AGE_KEY/" "$SOPS_YAML"

# Re-encrypt all secrets with the new key
echo "Re-encrypting secrets..."
sops updatekeys secrets/secrets.yaml

echo ""
echo "Success! Rabbit host key configured."
echo "You can now run: ./deploy-rabbit.sh"

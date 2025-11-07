#!/usr/bin/env bash
# Deploy script for updating system packages on Raspberry Pi 5 (mole)
# This updates the system-level Nix packages shared by all users
#
# Usage: ./deploy-pi.sh [user@]hostname
# Example: ./deploy-pi.sh pi@192.168.1.219

set -e

# Configuration
PI_USER="${1:-klaus@192.168.1.219}"

echo "=================================================="
echo "  Updating Raspberry Pi 5 System Packages"
echo "=================================================="
echo "Target: $PI_USER"
echo ""

# Upload latest system-packages.nix
echo "Uploading system-packages.nix..."
scp hosts/mole/system-packages.nix "$PI_USER:/tmp/"

# Update system packages
echo ""
echo "Updating system packages..."
ssh "$PI_USER" 'bash' <<'EOF'
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  echo "Installing updated packages to /nix/var/nix/profiles/default..."
  sudo env PATH="$PATH" nix --extra-experimental-features 'nix-command flakes' profile install \
    --profile /nix/var/nix/profiles/default \
    --file /tmp/system-packages.nix

  echo "System packages updated!"
EOF

echo ""
echo "=================================================="
echo "  Update Complete!"
echo "=================================================="
echo ""
echo "System packages have been updated."
echo ""
echo "To update user configurations:"
echo "  klaus: ssh klaus@192.168.1.219 'cd /opt/nixfiles && git pull && home-manager switch --flake .#pi5-klaus'"
echo "  kids:  ssh klaus@192.168.1.219 'sudo -u kids home-manager switch --flake /opt/nixfiles#pi5-kids'"
echo ""

#!/usr/bin/env bash
# Generic script to build SD card image for NixOS hosts
# Only works for aarch64 (Raspberry Pi) hosts
#
# Usage: ./build-image.sh <hostname>

set -e

# Function to get host architecture
get_host_arch() {
    case "$1" in
        rabbit|hetzner-pony)
            echo "x86_64-linux"
            ;;
        mole)
            echo "aarch64-linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <hostname>"
    echo ""
    echo "Builds an SD card image for the specified host."
    echo "Only works for ARM-based hosts (Raspberry Pi, etc.)"
    echo ""
    echo "Available hosts:"
    echo "  - mole (Raspberry Pi 500)"
    echo ""
    echo "Example:"
    echo "  $0 mole"
    exit 1
fi

HOSTNAME="$1"
ARCH=$(get_host_arch "$HOSTNAME")

if [ "$ARCH" = "unknown" ]; then
    echo "Error: Unknown host '$HOSTNAME'"
    echo "Available hosts: mole"
    exit 1
fi

if [ "$ARCH" != "aarch64-linux" ]; then
    echo "Error: Host '$HOSTNAME' is not an ARM-based system (arch: $ARCH)"
    echo "SD card images are only for ARM systems like Raspberry Pi."
    echo ""
    echo "For x86_64 systems, use: ./infect.sh $HOSTNAME"
    exit 1
fi

echo "=================================================="
echo "  Building NixOS SD Image for $HOSTNAME"
echo "=================================================="
echo "Architecture: $ARCH"
echo ""
echo "This may take 30-60 minutes on first build..."
echo "Building with QEMU emulation (slower) or remote builder if configured."
echo ""

# Build the SD image
nix build ".#nixosConfigurations.$HOSTNAME.config.system.build.sdImage" \
  --system "$ARCH" \
  --extra-platforms "$ARCH"

echo ""
echo "=================================================="
echo "  SD Image built successfully!"
echo "=================================================="
echo ""
echo "Image location: ./result/sd-image/*.img"
ls -lh ./result/sd-image/*.img
echo ""
echo "Next steps:"
echo "  1. Flash to SD card: ./burn-image.sh $HOSTNAME /dev/sdX"
echo "     (Replace /dev/sdX with your SD card device)"
echo ""
echo "  Or manually:"
echo "  1. Find SD card device: lsblk"
echo "  2. Unmount if mounted: sudo umount /dev/sdX*"
echo "  3. Flash: sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync"
echo ""

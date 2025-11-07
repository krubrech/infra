#!/usr/bin/env bash
# Script to safely burn NixOS SD card image to device
# Includes safety checks to prevent accidental system disk overwrite
#
# Usage: ./burn-image.sh <hostname> <device>

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

# Convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 )) MB"
    else
        echo "$(( bytes / 1073741824 )) GB"
    fi
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <hostname> <device>"
    echo ""
    echo "Burns NixOS SD card image to the specified device."
    echo ""
    echo "Arguments:"
    echo "  hostname  - Name of the host (e.g., mole)"
    echo "  device    - SD card device (e.g., /dev/sdb or /dev/mmcblk0)"
    echo ""
    echo "Examples:"
    echo "  $0 mole /dev/sdb"
    echo "  $0 mole /dev/mmcblk0"
    echo ""
    echo "To find your SD card device, run: lsblk"
    exit 1
fi

HOSTNAME="$1"
DEVICE="$2"
ARCH=$(get_host_arch "$HOSTNAME")

if [ "$ARCH" = "unknown" ]; then
    echo "Error: Unknown host '$HOSTNAME'"
    exit 1
fi

if [ "$ARCH" != "aarch64-linux" ]; then
    echo "Error: Host '$HOSTNAME' is not a Raspberry Pi"
    echo "This script is only for burning SD card images for ARM systems."
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Check if result/sd-image exists
IMAGE_FILE=$(ls -1 result/sd-image/*.img 2>/dev/null | head -n1)
if [ -z "$IMAGE_FILE" ]; then
    echo "Error: No SD card image found in result/sd-image/"
    echo ""
    echo "Build the image first with: ./build-image.sh $HOSTNAME"
    exit 1
fi

echo "Found image: $IMAGE_FILE"
IMAGE_SIZE=$(stat -c%s "$IMAGE_FILE")
echo "Image size: $(bytes_to_human $IMAGE_SIZE)"
echo ""

# Safety check: Verify device exists
if [ ! -b "$DEVICE" ]; then
    echo "Error: Device $DEVICE does not exist or is not a block device"
    echo ""
    echo "List available devices with: lsblk"
    exit 1
fi

# Safety check: Get device info
DEVICE_NAME=$(basename "$DEVICE")
SYS_PATH="/sys/block/$DEVICE_NAME"

# Handle partition devices (e.g., /dev/sdb1 -> /dev/sdb)
if [ ! -d "$SYS_PATH" ]; then
    # This might be a partition, try parent device
    PARENT_DEVICE=$(lsblk -ndo PKNAME "$DEVICE" 2>/dev/null || echo "")
    if [ -n "$PARENT_DEVICE" ]; then
        echo "Warning: $DEVICE is a partition. Using parent device /dev/$PARENT_DEVICE"
        DEVICE="/dev/$PARENT_DEVICE"
        DEVICE_NAME="$PARENT_DEVICE"
        SYS_PATH="/sys/block/$DEVICE_NAME"
    fi
fi

# Safety check: Verify it's removable (SD card/USB)
if [ -f "$SYS_PATH/removable" ]; then
    REMOVABLE=$(cat "$SYS_PATH/removable")
    if [ "$REMOVABLE" != "1" ]; then
        echo "=================================================="
        echo "  ERROR: Device is not marked as removable!"
        echo "=================================================="
        echo ""
        echo "Device $DEVICE is not removable. This might be a system disk."
        echo "Refusing to continue for safety."
        echo ""
        echo "If you're sure this is correct, you'll need to modify this script."
        exit 1
    fi
else
    echo "Warning: Cannot verify if device is removable"
fi

# Safety check: Get device size
DEVICE_SIZE=$(blockdev --getsize64 "$DEVICE")
DEVICE_SIZE_GB=$(( DEVICE_SIZE / 1073741824 ))
echo "Device: $DEVICE"
echo "Device size: $(bytes_to_human $DEVICE_SIZE) (${DEVICE_SIZE_GB} GB)"

# Safety check: Size should be reasonable for SD card (not > 64GB)
if [ $DEVICE_SIZE_GB -gt 64 ]; then
    echo "=================================================="
    echo "  ERROR: Device is larger than 64 GB!"
    echo "=================================================="
    echo ""
    echo "Device $DEVICE is ${DEVICE_SIZE_GB} GB, which is unusually large for an SD card."
    echo "This might be a system disk. Refusing to continue for safety."
    echo ""
    echo "If this is really a large SD card, you'll need to modify this script."
    exit 1
fi

# Safety check: Make sure it's not mounted as root or system partition
MOUNT_POINTS=$(lsblk -no MOUNTPOINT "$DEVICE" 2>/dev/null | grep -v '^$' || true)
if echo "$MOUNT_POINTS" | grep -q '^/$'; then
    echo "=================================================="
    echo "  ERROR: Device contains root filesystem!"
    echo "=================================================="
    echo ""
    echo "Device $DEVICE is mounted as /. This is your system disk!"
    echo "Refusing to continue."
    exit 1
fi

if echo "$MOUNT_POINTS" | grep -qE '^/(boot|home|usr|var)$'; then
    echo "=================================================="
    echo "  ERROR: Device contains system partition!"
    echo "=================================================="
    echo ""
    echo "Device $DEVICE contains a critical system partition."
    echo "Refusing to continue."
    exit 1
fi

# Show device info
echo ""
echo "=================================================="
echo "  Device Information"
echo "=================================================="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo ""

# Final confirmation
echo "=================================================="
echo "  WARNING: ALL DATA ON $DEVICE WILL BE DESTROYED!"
echo "=================================================="
echo ""
echo "Image: $IMAGE_FILE"
echo "Target: $DEVICE ($(bytes_to_human $DEVICE_SIZE))"
echo ""
read -p "Type 'YES' to continue: " confirm

if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Unmounting any mounted partitions on $DEVICE..."
for part in $(lsblk -ln -o NAME "$DEVICE" | tail -n +2); do
    if mountpoint -q "/dev/$part" 2>/dev/null; then
        echo "Unmounting /dev/$part..."
        umount "/dev/$part" || true
    fi
done

echo ""
echo "Writing image to $DEVICE..."
echo "This will take several minutes..."
echo ""

# Burn the image with progress
dd if="$IMAGE_FILE" of="$DEVICE" bs=4M status=progress conv=fsync

echo ""
echo "Syncing..."
sync

echo ""
echo "=================================================="
echo "  Image written successfully!"
echo "=================================================="
echo ""
echo "You can now:"
echo "  1. Safely remove the SD card"
echo "  2. Insert it into your Raspberry Pi"
echo "  3. Boot the device"
echo ""
echo "Initial credentials:"
echo "  - root: nixos"
echo "  - klaus: changeme"
echo "  - kids: kids"
echo ""
echo "After first boot, SSH to the device and get its age key:"
echo "  ssh root@192.168.1.219"
echo "  nix shell nixpkgs#ssh-to-age -c sh -c 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'"
echo ""

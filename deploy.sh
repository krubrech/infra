#!/usr/bin/env bash
# Generic deploy script for NixOS hosts
# Builds and deploys remotely to avoid local resource usage
#
# Usage: ./deploy.sh <hostname> [mode]

set -e

# Function to get host details
get_host_info() {
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
    echo "Usage: $0 <hostname> [mode]"
    echo ""
    echo "Arguments:"
    echo "  hostname  - Name of the host to deploy (rabbit, mole)"
    echo "  mode      - Deployment mode: switch (default), boot, or test"
    echo ""
    echo "Modes:"
    echo "  switch - Build and activate immediately (default)"
    echo "  boot   - Build and stage for next reboot (safe)"
    echo "  test   - Build and activate temporarily (reverts on reboot)"
    echo ""
    echo "Examples:"
    echo "  $0 mole"
    echo "  $0 rabbit boot"
    exit 1
fi

HOSTNAME="$1"
MODE="${2:-switch}"
IP=$(get_host_info "$HOSTNAME")
HOST="root@$IP"

case "$MODE" in
  switch)
    echo "Building and activating $HOSTNAME configuration on $HOST..."
    nixos-rebuild switch --flake ".#$HOSTNAME" \
      --target-host "$HOST" \
      --build-host "$HOST"
    echo "Deployment complete! Changes are active."
    ;;
  boot)
    echo "Building and staging $HOSTNAME configuration on $HOST..."
    nixos-rebuild boot --flake ".#$HOSTNAME" \
      --target-host "$HOST" \
      --build-host "$HOST"
    echo "Configuration staged! Reboot to activate. If SSH fails, use rescue mode to rollback."
    ;;
  test)
    echo "Building and testing $HOSTNAME configuration on $HOST (won't persist)..."
    nixos-rebuild test --flake ".#$HOSTNAME" \
      --target-host "$HOST" \
      --build-host "$HOST" \
      --verbose
    echo "Test deployment complete! Changes active but won't survive reboot."
    ;;
  *)
    echo "Error: Invalid mode '$MODE'"
    echo "Valid modes: switch, boot, test"
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Deploy script for rabbit host
# Builds and deploys remotely to avoid local resource usage
# Detects if running on rabbit itself and deploys locally

set -e

HOST="root@91.98.95.99"
MODE="${1:-switch}"

# Detect if we're running on rabbit itself
if [ "$(hostname)" = "rabbit" ]; then
  echo "Running on rabbit - deploying locally"
  REMOTE_FLAGS=""
  SUDO="sudo"
else
  echo "Running remotely - deploying to $HOST"
  REMOTE_FLAGS="--target-host $HOST --build-host $HOST"
  SUDO=""
fi

case "$MODE" in
  switch)
    echo "Building and activating rabbit configuration..."
    $SUDO nixos-rebuild switch --flake .#rabbit $REMOTE_FLAGS
    echo "Deployment complete! Changes are active."
    ;;
  boot)
    echo "Building and staging rabbit configuration..."
    $SUDO nixos-rebuild boot --flake .#rabbit $REMOTE_FLAGS
    echo "Configuration staged! Reboot to activate. If SSH fails, use rescue mode to rollback."
    ;;
  test)
    echo "Building and testing rabbit configuration (won't persist)..."
    $SUDO nixos-rebuild test --flake .#rabbit $REMOTE_FLAGS --verbose
    echo "Test deployment complete! Changes active but won't survive reboot."
    ;;
  *)
    echo "Usage: $0 [switch|boot|test]"
    echo "  switch - Build and activate immediately (default)"
    echo "  boot   - Build and stage for next reboot (safe)"
    echo "  test   - Build and activate temporarily (reverts on reboot)"
    exit 1
    ;;
esac

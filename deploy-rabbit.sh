#!/usr/bin/env bash
# Deploy script for rabbit host
# Builds and deploys remotely to avoid local resource usage

set -e

HOST="root@91.98.95.99"
MODE="${1:-switch}"

case "$MODE" in
  switch)
    echo "Building and activating rabbit configuration on $HOST..."
    nixos-rebuild switch --flake .#rabbit \
      --target-host "$HOST" \
      --build-host "$HOST"
    echo "Deployment complete! Changes are active."
    ;;
  boot)
    echo "Building and staging rabbit configuration on $HOST..."
    nixos-rebuild boot --flake .#rabbit \
      --target-host "$HOST" \
      --build-host "$HOST"
    echo "Configuration staged! Reboot to activate. If SSH fails, use rescue mode to rollback."
    ;;
  test)
    echo "Building and testing rabbit configuration on $HOST (won't persist)..."
    nixos-rebuild test --flake .#rabbit \
      --target-host "$HOST" \
      --build-host "$HOST"
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

#!/usr/bin/env bash
set -euo pipefail

# Add current machine's SSH public key to the trusted keys directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="$SCRIPT_DIR/ssh-keys"
HOSTNAME=$(hostname)
KEY_FILE="$KEYS_DIR/$HOSTNAME.pub"

mkdir -p "$KEYS_DIR"

echo "Adding SSH public key for machine: $HOSTNAME"

# Try to get key from ssh-agent first, otherwise fall back to ~/.ssh
if ssh-add -L 2>/dev/null | head -n1 > "$KEY_FILE"; then
    echo "✓ Added key from ssh-agent"
elif cat ~/.ssh/id_*.pub 2>/dev/null | head -n1 > "$KEY_FILE"; then
    echo "✓ Added key from ~/.ssh/"
else
    echo "✗ No SSH public key found"
    echo "  Generate one with: ssh-keygen -t ed25519"
    exit 1
fi

echo "✓ Key saved to: $KEY_FILE"
echo ""
echo "Run 'git add ssh-keys/$HOSTNAME.pub' to commit it"

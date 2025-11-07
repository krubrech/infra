#!/usr/bin/env bash
# Setup script for Raspberry Pi 5 (mole) with Nix package manager
# This script installs Nix, system packages, and home-manager for all users
#
# Usage: ./setup-pi.sh [user@]hostname
# Example: ./setup-pi.sh pi@192.168.1.219

set -e

# Configuration
PI_USER="${1:-pi@192.168.1.219}"
KLAUS_GITHUB="https://github.com/krubrech/nixfiles.git"

echo "=================================================="
echo "  Raspberry Pi 5 Nix Setup"
echo "=================================================="
echo "Target: $PI_USER"
echo ""

# Step 1: Install Nix on the Pi
echo "Step 1/6: Installing Nix package manager..."
ssh "$PI_USER" 'bash' <<'EOF'
  # Check if Nix is already installed
  if [ -d /nix ]; then
    echo "Nix is already installed, skipping..."
  else
    echo "Installing Nix multi-user..."
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes

    # Source nix
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

    echo "Nix installed successfully!"
  fi
EOF

# Step 2: Create users if they don't exist
echo ""
echo "Step 2/6: Creating users (klaus, kids)..."
ssh "$PI_USER" 'sudo bash' <<'EOF'
  # Create klaus user if doesn't exist
  if ! id klaus &>/dev/null; then
    echo "Creating klaus user..."
    sudo adduser --disabled-password --gecos "Klaus" klaus
    sudo usermod -aG sudo klaus
  else
    echo "klaus user already exists"
  fi

  # Create kids user if doesn't exist
  if ! id kids &>/dev/null; then
    echo "Creating kids user..."
    sudo adduser --disabled-password --gecos "Kids" kids
  else
    echo "kids user already exists"
  fi

  # Set initial passwords (prompt user to change later)
  echo "klaus:changeme" | sudo chpasswd
  echo "kids:kids" | sudo chpasswd

  echo "Users created. Remember to change passwords!"
EOF

# Step 3: Install system packages
echo ""
echo "Step 3/6: Installing system packages (RetroArch, cores, etc.)..."
scp hosts/mole/system-packages.nix "$PI_USER:/tmp/"
ssh "$PI_USER" 'bash' <<'EOF'
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  echo "Installing system packages to /nix/var/nix/profiles/default..."
  sudo nix profile install \
    --profile /nix/var/nix/profiles/default \
    --file /tmp/system-packages.nix

  # Make sure system packages are in PATH for all users
  echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' | sudo tee -a /etc/profile.d/nix-system.sh

  echo "System packages installed!"
EOF

# Step 4: Install home-manager
echo ""
echo "Step 4/6: Installing home-manager..."
ssh "$PI_USER" 'bash' <<'EOF'
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Install home-manager for current user
  nix run home-manager/master -- init --switch

  echo "home-manager installed!"
EOF

# Step 5: Setup klaus user home-manager
echo ""
echo "Step 5/6: Setting up klaus user..."
ssh "$PI_USER" 'sudo -u klaus bash' <<EOF
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Clone nixfiles repo
  if [ ! -d /home/klaus/nixfiles ]; then
    git clone $KLAUS_GITHUB /home/klaus/nixfiles
  else
    cd /home/klaus/nixfiles && git pull
  fi

  # Install home-manager and apply pi5-klaus config
  nix run home-manager/master -- init
  cd /home/klaus/nixfiles
  home-manager switch --flake .#pi5-klaus

  echo "klaus home-manager configured!"
EOF

# Step 6: Setup kids user home-manager
echo ""
echo "Step 6/6: Setting up kids user..."
ssh "$PI_USER" 'sudo -u kids bash' <<EOF
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Clone nixfiles repo for kids
  if [ ! -d /home/kids/nixfiles ]; then
    git clone $KLAUS_GITHUB /home/kids/nixfiles
  else
    cd /home/kids/nixfiles && git pull
  fi

  # Install home-manager and apply pi5-kids config
  nix run home-manager/master -- init
  cd /home/kids/nixfiles
  home-manager switch --flake .#pi5-kids

  echo "kids home-manager configured!"
EOF

# Configure auto-login for kids user
echo ""
echo "Configuring auto-login for kids user..."
ssh "$PI_USER" 'sudo bash' <<'EOF'
  # Configure lightdm for auto-login
  if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#autologin-user=.*/autologin-user=kids/' /etc/lightdm/lightdm.conf
    sudo sed -i 's/^autologin-user=.*/autologin-user=kids/' /etc/lightdm/lightdm.conf
  else
    # Create lightdm config if it doesn't exist
    echo "[Seat:*]" | sudo tee /etc/lightdm/lightdm.conf
    echo "autologin-user=kids" | sudo tee -a /etc/lightdm/lightdm.conf
  fi

  echo "Auto-login configured for kids user"
EOF

echo ""
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Your Raspberry Pi is now configured with:"
echo "  - Nix package manager"
echo "  - RetroArch + cores (NES, SNES, N64, PS1, GBA, Genesis, etc.)"
echo "  - Luanti (Minetest)"
echo "  - home-manager for klaus and kids users"
echo ""
echo "Users:"
echo "  - klaus (password: changeme) - Admin user, SSH access"
echo "  - kids (password: kids) - Auto-login, RetroArch gaming"
echo ""
echo "Next steps:"
echo "  1. Change passwords: ssh klaus@192.168.1.219 'passwd'"
echo "  2. Upload ROMs to /home/kids/Games/"
echo "  3. Reboot the Pi to start auto-login: ssh $PI_USER 'sudo reboot'"
echo ""
echo "To update configurations later:"
echo "  - System packages: ./hosts/mole/deploy-pi.sh"
echo "  - User configs: home-manager switch --flake ~/nixfiles#pi5-klaus"
echo ""

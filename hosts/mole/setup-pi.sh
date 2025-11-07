#!/usr/bin/env bash
# Setup script for Raspberry Pi 5 (mole) with Nix package manager
# This script installs Nix, system packages, and home-manager for all users
#
# Usage: ./setup-pi.sh [user@]hostname
# Example: ./setup-pi.sh pi@192.168.1.219

set -e

# Configuration
PI_USER="${1:-klaus@192.168.1.219}"
KLAUS_GITHUB="git@github.com:krubrech/nixfiles.git"

echo "=================================================="
echo "  Raspberry Pi 5 Nix Setup"
echo "=================================================="
echo "Target: $PI_USER"
echo ""

# Step 0: Install SSH key if not already present
echo "Step 0/6: Installing SSH key for passwordless access..."
if ssh -o PasswordAuthentication=no -o ConnectTimeout=5 "$PI_USER" exit 2>/dev/null; then
  echo "SSH key already installed, skipping..."
else
  echo "Installing SSH key (you'll need to enter password once)..."
  SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
  ssh "$PI_USER" "mkdir -p ~/.ssh && echo '$SSH_KEY' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
  echo "SSH key installed! All subsequent commands will be passwordless."
fi

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

  # Enable experimental features permanently
  echo "Enabling experimental features in nix.conf..."
  sudo mkdir -p /etc/nix
  if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
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
  sudo env PATH="$PATH" nix --extra-experimental-features 'nix-command flakes' profile install \
    --profile /nix/var/nix/profiles/default \
    --file /tmp/system-packages.nix

  # Make sure system packages are in PATH for all users (idempotent)
  if [ ! -f /etc/profile.d/nix-system.sh ]; then
    cat <<'PROFILE_SCRIPT' | sudo tee /etc/profile.d/nix-system.sh
# Add system-wide Nix packages to PATH
if [[ ":$PATH:" != *":/nix/var/nix/profiles/default/bin:"* ]]; then
  export PATH="/nix/var/nix/profiles/default/bin:$PATH"
fi
PROFILE_SCRIPT
    sudo chmod +r /etc/profile.d/nix-system.sh
  fi

  echo "System packages installed!"
EOF

# Step 4: Install home-manager
echo ""
echo "Step 4/6: Installing home-manager..."
ssh "$PI_USER" 'bash' <<'EOF'
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Install home-manager for current user
  nix --extra-experimental-features 'nix-command flakes' run home-manager/master -- init --switch

  echo "home-manager installed!"
EOF

# Step 5: Setup klaus user home-manager
echo ""
echo "Step 5/6: Setting up klaus user..."

# Use SSH agent forwarding to clone from GitHub without copying keys
# Need to preserve SSH_AUTH_SOCK when using sudo
ssh -A "$PI_USER" 'bash' <<EOF
  AUTH_SOCK=\$SSH_AUTH_SOCK

  # Clone nixfiles to /opt/nixfiles (system location)
  # Klaus owns it and can write, others can read
  sudo -u klaus bash -c "
    export SSH_AUTH_SOCK=\$AUTH_SOCK

    # Add GitHub to known_hosts for klaus
    mkdir -p /home/klaus/.ssh
    ssh-keyscan github.com >> /home/klaus/.ssh/known_hosts 2>/dev/null
  "

  # Create /opt/nixfiles and set ownership to klaus
  sudo mkdir -p /opt/nixfiles
  sudo chown klaus:klaus /opt/nixfiles

  # Clone or update nixfiles as klaus user
  sudo -u klaus bash -c "
    export SSH_AUTH_SOCK=\$AUTH_SOCK
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

    if [ ! -d /opt/nixfiles/.git ]; then
      git clone $KLAUS_GITHUB /opt/nixfiles
    else
      cd /opt/nixfiles && git pull
    fi
  "

  # Create symlink for convenience
  sudo -u klaus ln -sfn /opt/nixfiles /home/klaus/nixfiles

  # Apply klaus's home-manager config
  sudo -u klaus bash -c "
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

    # Install home-manager and apply pi5-klaus config
    nix run home-manager/master -- init
    . /home/klaus/.nix-profile/etc/profile.d/hm-session-vars.sh
    cd /opt/nixfiles
    home-manager switch --flake .#pi5-klaus

    echo 'klaus home-manager configured!'
  "
EOF

# Step 6: Setup kids user home-manager
echo ""
echo "Step 6/6: Setting up kids user..."

# Kids user will use nixfiles from /opt (readable by all users)
ssh "$PI_USER" 'sudo -u kids bash' <<'EOF'
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Mark /opt/nixfiles as a safe directory for Git (owned by different user)
  git config --global --add safe.directory /opt/nixfiles

  # Apply pi5-kids config from /opt/nixfiles (readable by all users)
  # This will install home-manager as part of the switch
  nix run home-manager/master -- switch --flake /opt/nixfiles#pi5-kids

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
echo "  - Klaus config: home-manager switch --flake /opt/nixfiles#pi5-klaus"
echo "  - Kids config (as klaus): sudo -u kids home-manager switch --flake /opt/nixfiles#pi5-kids"
echo "  - Nixfiles are at: /opt/nixfiles (symlinked from ~/nixfiles)"
echo ""

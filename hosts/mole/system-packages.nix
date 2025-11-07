# System-level Nix packages for Raspberry Pi 5 (mole)
# These packages will be installed in /nix/var/nix/profiles/default
# and available to all users on the system
#
# To apply: sudo nix profile install --profile /nix/var/nix/profiles/default --file ./system-packages.nix

{ pkgs ? import <nixpkgs> { system = "aarch64-linux"; } }:

with pkgs; [
  # Gaming - RetroArch with cores
  retroarch

  # RetroArch cores for various systems
  libretro.beetle-psx-hw       # PlayStation 1
  libretro.snes9x              # Super Nintendo
  libretro.mgba                # Game Boy Advance
  libretro.mupen64plus         # Nintendo 64
  libretro.genesis-plus-gx     # Sega Genesis/Mega Drive
  libretro.nestopia            # NES
  libretro.beetle-pce-fast     # PC Engine/TurboGrafx-16
  libretro.gambatte            # Game Boy / Game Boy Color
  libretro.dolphin             # GameCube / Wii

  # Luanti (formerly Minetest)
  minetest

  # Web browser
  firefox

  # File manager
  xfce.thunar

  # System utilities
  htop
  vim
  git
  wget
  curl
  tree
  ncdu

  # Archive tools
  p7zip
  unzip
  unrar

  # Network tools
  nmap
  iftop

  # Media tools
  vlc
]

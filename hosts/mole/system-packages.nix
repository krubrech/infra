# System-level Nix packages for Raspberry Pi 5 (mole)
# These packages will be installed in /nix/var/nix/profiles/default
# and available to all users on the system
#
# To apply: sudo nix profile install --profile /nix/var/nix/profiles/default --file ./system-packages.nix

{ pkgs ? import <nixpkgs> {
    system = "aarch64-linux";
    config.allowUnfree = true;
  }
}:

let
  # On Raspberry Pi OS (non-NixOS), GPU drivers are in system paths
  # We create simple wrappers that set LD_LIBRARY_PATH to find them
  # This is the standard approach for Nix-on-non-NixOS setups

  retroarch-wrapped = pkgs.writeShellScriptBin "retroarch" ''
    export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/usr/lib:$LD_LIBRARY_PATH"
    exec ${pkgs.retroarch}/bin/retroarch "$@"
  '';

  luanti-wrapped = pkgs.writeShellScriptBin "luanti" ''
    export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/usr/lib:$LD_LIBRARY_PATH"
    exec ${pkgs.luanti-client}/bin/luanti "$@"
  '';
in

with pkgs; [
  # LD_LIBRARY_PATH-wrapped graphical applications
  # These wrappers allow Nix packages to find system GPU drivers
  retroarch-wrapped
  luanti-wrapped

  # RetroArch cores for various systems
  libretro.beetle-psx-hw       # PlayStation 1
  libretro.snes9x              # Super Nintendo
  libretro.mgba                # Game Boy Advance
  libretro.mupen64plus         # Nintendo 64
  libretro.genesis-plus-gx     # Sega Genesis/Mega Drive
  libretro.nestopia            # NES
  libretro.beetle-pce-fast     # PC Engine/TurboGrafx-16
  libretro.gambatte            # Game Boy / Game Boy Color

  # Graphics and audio libraries for RetroArch
  mesa
  libdrm
  libGL
  libGLU
  vulkan-loader
  vulkan-headers
  SDL2
  alsa-lib
  pulseaudio
  wayland
  wayland-protocols
  libxkbcommon

  # System utilities
  htop
  git
  wget
  curl
  tree
  ncdu
  neovim

  # Archive tools
  p7zip
  unzip
  unrar

  # Network tools
  nmap
  iftop

  # Desktop applications
  firefox

  # Media tools
  vlc
]

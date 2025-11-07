{ config, lib, pkgs, inputs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  networking.hostName = "mole";
  time.timeZone = "Europe/Brussels";

  # SD image configuration
  sdImage.compressImage = false;  # Faster to build, you can compress later if needed

  # SSH access
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;  # Enable for initial setup
    settings.PermitRootLogin = "yes";  # Enable for initial setup
  };

  # Set a default root password for initial access (change this after first boot!)
  users.users.root.initialPassword = "nixos";

  # Configure sops to use SSH host keys (will be generated on first boot)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Firewall: Only SSH publicly accessible
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH only
  };

  # mDNS for local discovery (mole.local)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };

  # Automatically load all trusted SSH keys
  profiles.trustedKeys.enable = true;

  # Enable base profile
  profiles.base.enable = true;

  # Enable graphical environment with XFCE
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.lightdm = {
      enable = true;
      # Auto-login kids user to RetroArch
      autoLogin = {
        enable = true;
        user = "kids";
      };
    };
  };

  # Custom session for kids user that launches RetroArch
  services.displayManager.sessionCommands = ''
    # Launch RetroArch in fullscreen for kids user
    if [ "$USER" = "kids" ]; then
      ${pkgs.retroarch}/bin/retroarch --fullscreen &
    fi
  '';

  # Create klaus user (admin)
  users.users.klaus = {
    isNormalUser = true;
    initialPassword = "changeme";  # Set password for initial setup, change after first login
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    openssh.authorizedKeys.keys =
      let
        sshKeysDir = ../../ssh-keys;
        keyFiles = builtins.attrNames (builtins.readDir sshKeysDir);
        readKey = file: builtins.readFile (sshKeysDir + "/${file}");
      in
        map readKey (builtins.filter (f: lib.hasSuffix ".pub" f) keyFiles);
    # hashedPasswordFile = config.sops.secrets.klaus-password.path;  # TODO: Enable after sops setup
  };

  # Create kids user (limited, auto-login to RetroArch)
  users.users.kids = {
    isNormalUser = true;
    initialPassword = "kids";  # Set password for initial setup
    extraGroups = [ "audio" "video" ];
    # hashedPasswordFile = config.sops.secrets.kids-password.path;  # TODO: Enable after sops setup
  };

  # Configure sops secrets (commented out for initial SD image)
  # TODO: Uncomment after getting mole's age key and setting up secrets
  # sops.secrets.klaus-password = {
  #   sopsFile = ../../secrets/secrets.yaml;
  #   neededForUsers = true;
  # };

  # sops.secrets.kids-password = {
  #   sopsFile = ../../secrets/secrets.yaml;
  #   neededForUsers = true;
  # };

  # System packages for gaming
  environment.systemPackages = with pkgs; [
    # RetroArch and cores
    retroarch
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

    # Utilities
    firefox
    xfce.thunar
  ];

  # RetroArch configuration directory for kids user
  # This will be managed through home-manager in users/kids.nix

  # Hardware support is handled by sd-image-aarch64.nix module
  # No need for explicit Pi hardware config

  # Enable OpenGL for gaming
  hardware.graphics.enable = true;

  # Audio support
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;
    pulse.enable = true;
  };

  # Bluetooth support for game controllers
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
}

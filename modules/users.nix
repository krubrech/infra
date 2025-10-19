{ config, lib, pkgs, inputs, ... }:
let
  # Read all .pub files from ssh-keys directory
  sshKeysDir = ../ssh-keys;
  keyFiles = builtins.attrNames (builtins.readDir sshKeysDir);
  readKey = file: builtins.readFile (sshKeysDir + "/${file}");
  publicKeys = map readKey (builtins.filter (f: lib.hasSuffix ".pub" f) keyFiles);
in
{
  options.profiles.users.enable = lib.mkEnableOption "user accounts with trusted SSH keys";

  config = lib.mkIf config.profiles.users.enable {
    # Create klaus user
    users.users.klaus = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      openssh.authorizedKeys.keys = publicKeys;
      # Hashed password will be set from sops at runtime
      hashedPasswordFile = config.sops.secrets.klaus-password.path;
    };

    # Configure home-manager for klaus user
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = { inherit inputs; };
    home-manager.users.klaus = inputs.nixfiles.homeManagerModules.klaus;

    # Configure sops secret for klaus password (must be hashed with mkpasswd -m sha-512)
    sops.secrets.klaus-password = {
      sopsFile = ../secrets/secrets.yaml;
      neededForUsers = true;
    };

    # Configure sops secret for GitHub SSH key
    sops.secrets.github-krubrech-rabbit-ssh-key = {
      sopsFile = ../secrets/secrets.yaml;
      owner = "klaus";
      group = "users";
      mode = "0600";
    };
  };
}

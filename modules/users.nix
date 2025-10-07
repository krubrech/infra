{ config, lib, pkgs, ... }:
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

    # Configure sops secret for klaus password (must be hashed with mkpasswd -m sha-512)
    sops.secrets.klaus-password = {
      sopsFile = ../secrets/secrets.yaml;
      neededForUsers = true;
    };
  };
}

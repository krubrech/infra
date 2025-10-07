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
      # Initial password (plaintext, will be hashed automatically)
      initialPassword = builtins.readFile config.sops.secrets.klaus-password.path;
    };

    # Configure sops secret for klaus password
    sops.secrets.klaus-password = {
      sopsFile = ../secrets/secrets.yaml;
    };
  };
}

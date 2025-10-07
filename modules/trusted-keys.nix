{ config, lib, pkgs, ... }:
let
  # Read all .pub files from ssh-keys directory
  sshKeysDir = ../ssh-keys;
  keyFiles = builtins.attrNames (builtins.readDir sshKeysDir);
  readKey = file: builtins.readFile (sshKeysDir + "/${file}");
  publicKeys = map readKey (builtins.filter (f: lib.hasSuffix ".pub" f) keyFiles);
in
{
  options.profiles.trustedKeys.enable = lib.mkEnableOption "trusted SSH keys";

  config = lib.mkIf config.profiles.trustedKeys.enable {
    users.users.root.openssh.authorizedKeys.keys = publicKeys;
  };
}

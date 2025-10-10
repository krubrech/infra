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

    # Deploy SSH configuration to klaus home directory
    systemd.tmpfiles.rules = [
      "d /home/klaus/.ssh 0700 klaus users -"
      "L+ /home/klaus/.ssh/github - - - - ${config.sops.secrets.github-krubrech-rabbit-ssh-key.path}"
    ];

    # Configure SSH for GitHub
    environment.etc."ssh/ssh_config.d/10-klaus-github.conf".text = ''
      Host github.com
        HostName github.com
        User git
        IdentityFile /home/klaus/.ssh/github
        IdentitiesOnly yes
    '';

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

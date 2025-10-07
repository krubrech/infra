{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbuild;
in {
  options.services.nixbuild = {
    enable = mkEnableOption "nixbuild.net remote builders";

    sshKeyPath = mkOption {
      type = types.str;
      default = "/root/.ssh/nixbuild";
      description = "Path to the SSH private key for nixbuild.net";
    };

    maxJobs = mkOption {
      type = types.int;
      default = 100;
      description = "Maximum number of concurrent build jobs";
    };
  };

  config = mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      Host eu.nixbuild.net
      PubkeyAcceptedKeyTypes ssh-ed25519
      ServerAliveInterval 60
      IPQoS throughput
      IdentityFile ${cfg.sshKeyPath}
    '';

    programs.ssh.knownHosts = {
      nixbuild = {
        hostNames = [ "eu.nixbuild.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
      };
    };

    nix = {
      distributedBuilds = true;
      buildMachines = [
        { hostName = "eu.nixbuild.net";
          system = "x86_64-linux";
          maxJobs = cfg.maxJobs;
          supportedFeatures = [ "benchmark" "big-parallel" ];
        }
      ];
    };
  };
}

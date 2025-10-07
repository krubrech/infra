{ config, lib, pkgs, inputs, ... }:
{
  networking.hostName = "pony";
  time.timeZone = "Europe/Brussels";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ "YOUR@PUBKEY" ];

  # Role toggles (reusable across hosts)
  profiles.base.enable = true;
  profiles.reverseProxy.enable = true;     # from modules/nginx.nix

  # App declarations (generic; see modules/apps.nix)
  services.apps.instances = {

    # Example 1: run a flake-provided "app" (no Phoenix coupling)
    okato = {
      enable = true;
      user = "deployer";
      workDir = "/home/deployer/okato";
      # provide a program from an external flake input (if present)
      program = inputs ? my-phx-app
        then inputs.my-phx-app.apps.${pkgs.system}.serve-prod.program
        else "/usr/bin/false";
      env = {
        MIX_ENV = "prod";
        PORT = "4000";
      };
      environmentFile = "/home/deployer/okato/.env"; # SOPS-managed file
      ports = [ 4000 ];
      domains = [ "okato.codecanoe.com" ];
      healthcheck.path = "/";
    };
  };
}

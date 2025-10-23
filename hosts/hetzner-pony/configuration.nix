{ config, lib, pkgs, inputs, ... }:
{
  networking.hostName = "pony";
  time.timeZone = "Europe/Brussels";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ "YOUR@PUBKEY" ];

  # WireGuard VPN configuration
  sops.secrets.wireguard-pony-private-key = {
    sopsFile = ../../secrets/secrets.yaml;
  };

  profiles.wireguard = {
    enable = true;
    address = "10.100.0.1/24";
    privateKeyFile = config.sops.secrets.wireguard-pony-private-key.path;
    peers = [
      {
        name = "rabbit";
        publicKey = "IbkUODTxRUfUzJyApTJxVPdPco1PN6H93r5BtsG41g4=";
        allowedIPs = [ "10.100.0.2/32" ];
        endpoint = "rabbit:51820";
        persistentKeepalive = 25;
      }
      {
        name = "client";
        publicKey = "yrduKgtx0oU+OdqknWjavEtxN+yECjUYMTbydxxEGRo=";
        allowedIPs = [ "10.100.0.10/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # Firewall: Only SSH and WireGuard publicly accessible
  # Override nginx module's firewall settings to keep HTTP/HTTPS behind VPN
  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkForce [ 22 ];  # SSH only (force override nginx's 80/443)
    allowedUDPPorts = [ 51820 ];  # WireGuard
    # All other services (HTTP/HTTPS) only accessible via WireGuard (trusted interface wg0)
  };

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

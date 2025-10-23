{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.wireguard;
in
{
  options.profiles.wireguard = {
    enable = mkEnableOption "WireGuard VPN mesh network";

    privateKeyFile = mkOption {
      type = types.str;
      description = "Path to the private key file (managed by sops)";
    };

    address = mkOption {
      type = types.str;
      description = "WireGuard IP address with CIDR (e.g., 10.100.0.1/24)";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "WireGuard listen port";
    };

    peers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Peer name for reference";
          };
          publicKey = mkOption {
            type = types.str;
            description = "Peer's public key";
          };
          allowedIPs = mkOption {
            type = types.listOf types.str;
            description = "IP addresses this peer is allowed to use";
          };
          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Endpoint address (host:port) for peers with public IPs";
          };
          persistentKeepalive = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Keepalive interval in seconds (useful for NAT traversal)";
          };
        };
      });
      default = [];
      description = "List of WireGuard peers in the mesh";
    };
  };

  config = mkIf cfg.enable {
    # Enable WireGuard
    networking.wg-quick.interfaces.wg0 = {
      address = [ cfg.address ];
      listenPort = cfg.listenPort;
      privateKeyFile = cfg.privateKeyFile;

      peers = map (peer: {
        publicKey = peer.publicKey;
        allowedIPs = peer.allowedIPs;
      } // optionalAttrs (peer.endpoint != null) {
        endpoint = peer.endpoint;
      } // optionalAttrs (peer.persistentKeepalive != null) {
        persistentKeepalive = peer.persistentKeepalive;
      }) cfg.peers;
    };

    # Open WireGuard port in firewall
    networking.firewall.allowedUDPPorts = [ cfg.listenPort ];

    # Trust the WireGuard interface
    networking.firewall.trustedInterfaces = [ "wg0" ];

    # Enable IP forwarding for mesh routing
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}

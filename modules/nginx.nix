{ config, lib, pkgs, ... }:
let
  apps = config.services.apps.instances or {};
  vhosts = lib.attrsets.mapAttrs' (name: app:
    if (app.enable or false) && (app.domains or [] != [])
    then {
      name = builtins.head app.domains;
      value = {
        enableACME = true;
        forceSSL = true;
        root = lib.mkIf (app.type or "" == "static") app.root;
        locations."/" = lib.mkIf (app.type or "" != "static") {
          proxyPass = "http://127.0.0.1:${toString (builtins.head (app.ports or [0]))}";
        };
      };
    } else lib.attrsets.nameValuePair "__skip-${name}" {}
  ) apps;
  filtered = lib.filterAttrs (n: _: !lib.hasPrefix "__skip-" n) vhosts;
in {
  options.profiles.reverseProxy.enable = lib.mkEnableOption "nginx reverse proxy";
  config = lib.mkIf config.profiles.reverseProxy.enable {
    security.acme = {
      acceptTerms = true;
      defaults.email = "klausrubrecht@gmail.com";
    };
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = filtered;
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}

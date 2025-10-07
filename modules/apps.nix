{ config, lib, pkgs, ... }:
with lib;
let
  appOpts = { name, ... }: {
    options = {
      enable = mkEnableOption "app ${name}";
      type = mkOption { type = types.enum [ "process" "container" "static" ]; default = "process"; };
      user = mkOption { type = types.str; default = "app-${name}"; };
      group = mkOption { type = types.str; default = "app-${name}"; };
      workDir = mkOption { type = types.path; default = "/var/lib/${name}"; };
      program = mkOption { type = types.nullOr types.path; default = null; description = "Executable for type=process"; };
      environmentFile = mkOption { type = types.nullOr types.path; default = null; };
      env = mkOption { type = types.attrsOf types.str; default = {}; };
      ports = mkOption { type = types.listOf types.int; default = []; };
      domains = mkOption { type = types.listOf types.str; default = []; };
      healthcheck.path = mkOption { type = types.str; default = "/"; };
      after = mkOption { type = types.listOf types.str; default = [ "network-online.target" ]; };
      wants = mkOption { type = types.listOf types.str; default = [ "network-online.target" ]; };
      # container-specific
      image = mkOption { type = types.nullOr types.str; default = null; };
      dataDirs = mkOption { type = types.listOf types.path; default = []; };
      # static-specific
      root = mkOption { type = types.nullOr types.path; default = null; };
    };
    config = mkIf config.services.apps.instances.${name}.enable (
      let app = config.services.apps.instances.${name}; in
      {
        users.users.${app.user} = { isSystemUser = true; home = app.workDir; createHome = true; group = app.group; };
        users.groups.${app.group} = {};

        # process
        systemd.services."app-${name}" = mkIf (app.type == "process") {
          description = "App ${name}";
          after = app.after; wants = app.wants;
          serviceConfig = {
            User = app.user;
            WorkingDirectory = app.workDir;
            ExecStart = mkIf (app.program != null) app.program;
            Restart = "always"; RestartSec = 5;
            EnvironmentFile = mkIf (app.environmentFile != null) app.environmentFile;
          };
          environment = app.env;
          wantedBy = [ "multi-user.target" ];
        };

        # container
        virtualisation.oci-containers.containers."${name}" = mkIf (app.type == "container") {
          image = app.image;
          ports = map (p: "${toString p}:${toString p}") app.ports;
          environment = app.env;
          volumes = map (d: "${d}:${d}") app.dataDirs;
          user = app.user;
        };

        # firewall (open port for process services only; containers map ports themselves)
        networking.firewall.allowedTCPPorts = mkIf (app.type == "process" && app.ports != []) app.ports;
      }
    );
  };
in
{
  options.services.apps.instances = mkOption {
    type = types.attrsOf (types.submodule appOpts);
    default = {};
    description = "Declare apps to run on this host.";
  };
}

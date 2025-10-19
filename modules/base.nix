{ config, lib, pkgs, ... }:
{
  options.profiles.base.enable = lib.mkEnableOption "base profile";
  config = lib.mkIf config.profiles.base.enable {
    networking.useNetworkd = true;
    services.resolved.enable = true;
    security.sudo.wheelNeedsPassword = false;
    nixpkgs.config.allowUnfree = true;
    environment.systemPackages = with pkgs; [ htop git vim tmux ];
    system.stateVersion = "25.05";
  };
}

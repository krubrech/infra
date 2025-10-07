{ config, lib, pkgs, inputs, ... }:
{
  networking.hostName = "rabbit";
  time.timeZone = "Europe/Brussels";

  # SSH access
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };

  # Automatically load all trusted SSH keys
  profiles.trustedKeys.enable = true;

  # Enable graphical environment
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.lightdm.enable = true;
  };

  # Enable VNC for remote graphical access
  services.x11vnc = {
    enable = true;
    viewonly = false;
    auth = "/var/run/lightdm/root/:0";
    display = ":0";
    findauth = "guess";
    rfbport = 5900;
  };

  # Open VNC port in firewall
  networking.firewall.allowedTCPPorts = [ 5900 ];

  # Base profile
  profiles.base.enable = true;

  # Additional graphical packages
  environment.systemPackages = with pkgs; [
    firefox
    x11vnc
  ];
}

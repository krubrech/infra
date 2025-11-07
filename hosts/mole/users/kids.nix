{ config, pkgs, lib, ... }:

{
  # Minimal configuration for kids user - RetroArch only
  home.username = "kids";
  home.homeDirectory = "/home/kids";
  home.stateVersion = "25.05";

  # Minimal nix config for kids user
  nix.package = lib.mkForce pkgs.nix;
  nix.settings = {};

  # No additional packages - everything provided by system
  home.packages = [];

  # RetroArch configuration with kid-friendly settings
  xdg.configFile."retroarch/retroarch.cfg".text = ''
    # Video settings
    video_fullscreen = "true"
    video_windowed_fullscreen = "true"
    video_smooth = "true"
    video_threaded = "true"
    video_vsync = "true"

    # Audio settings
    audio_enable = "true"
    audio_driver = "pulse"
    audio_volume = "0"  # Normal volume (0 dB)

    # Input settings
    input_autodetect_enable = "true"
    input_joypad_driver = "udev"
    input_max_users = "4"

    # Menu settings
    menu_driver = "xmb"
    xmb_menu_color_theme = "4"  # Kid-friendly theme
    menu_show_advanced_settings = "false"
    menu_show_core_updater = "false"
    menu_show_online_updater = "false"

    # Directory settings
    rgui_browser_directory = "/home/kids/Games"
    content_history_dir = "/home/kids/.config/retroarch/history"
    screenshot_directory = "/home/kids/Screenshots"

    # Save settings
    savestate_auto_save = "true"
    savestate_auto_load = "true"
    save_file_compression = "true"
    savestate_file_compression = "true"

    # Disable quit confirm for easier navigation
    quit_press_twice = "false"

    # Hotkeys - simplified for kids
    input_exit_emulator = "escape"
    input_menu_toggle = "f1"
    input_screenshot = "f8"

    # Parental controls
    # Note: These can be further configured in RetroArch's UI if needed
    # menu_enable_kiosk_mode = "false"  # Can be enabled for stricter control
  '';

  # Create Games directory structure (shared ROMs location)
  home.file."Games/.keep".text = "Place game ROMs in subdirectories";
  home.file."Games/NES/.keep".text = "";
  home.file."Games/SNES/.keep".text = "";
  home.file."Games/N64/.keep".text = "";
  home.file."Games/PS1/.keep".text = "";
  home.file."Games/GBA/.keep".text = "";
  home.file."Games/GB/.keep".text = "";
  home.file."Games/Genesis/.keep".text = "";

  # Screenshots directory
  home.file."Screenshots/.keep".text = "";

  # Simple .xsession to launch RetroArch on login
  home.file.".xsession" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Launch RetroArch in fullscreen
      exec ${pkgs.retroarch}/bin/retroarch --fullscreen
    '';
  };

  programs.home-manager.enable = true;
}

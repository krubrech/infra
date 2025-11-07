{ config, pkgs, lib, inputs, ... }:

{
  # Import the klaus-nixos base configuration from nixfiles
  imports = [ inputs.nixfiles.homeManagerModules.klaus-nixos ];

  # Prevent evaluation of i686/32-bit packages on ARM
  nixpkgs.config = {
    allowUnsupportedSystem = false;
  };

  # Gaming-specific additions for mole
  home.packages = with pkgs; [
    # Note: steam-run removed - requires i686/32-bit x86 libs (not available on ARM)

    # File management for ROMs
    p7zip
    unzip

    # Network tools for remote management
    htop
    ncdu
  ];

  # RetroArch configuration preferences
  xdg.configFile."retroarch/retroarch.cfg".text = ''
    # Video settings
    video_fullscreen = "true"
    video_windowed_fullscreen = "true"
    video_smooth = "true"
    video_threaded = "true"

    # Audio settings
    audio_enable = "true"
    audio_driver = "pulse"

    # Input settings
    input_autodetect_enable = "true"
    input_joypad_driver = "udev"

    # Menu settings
    menu_driver = "xmb"
    xmb_menu_color_theme = "10"

    # Directory settings
    rgui_browser_directory = "/home/klaus/ROMs"
    content_history_dir = "/home/klaus/.config/retroarch/history"

    # Save settings
    savestate_auto_save = "true"
    savestate_auto_load = "true"

    # Hotkeys
    input_exit_emulator = "escape"
    input_menu_toggle = "f1"
  '';

  # Create ROMs directory structure
  home.file."ROMs/.keep".text = "";
  home.file."ROMs/NES/.keep".text = "";
  home.file."ROMs/SNES/.keep".text = "";
  home.file."ROMs/N64/.keep".text = "";
  home.file."ROMs/PS1/.keep".text = "";
  home.file."ROMs/GBA/.keep".text = "";
  home.file."ROMs/GB/.keep".text = "";
  home.file."ROMs/Genesis/.keep".text = "";
}

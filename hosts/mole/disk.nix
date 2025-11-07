{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/mmcblk0";  # SD card on Raspberry Pi
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "ef00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}

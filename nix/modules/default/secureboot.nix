{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.sbfde;
in
{
  config = lib.mkIf cfg.enable {
    boot = {
      initrd = {
        systemd = {
          enable = lib.mkDefault true;
          tpm2.enable = lib.mkDefault true;
          initrdBin = lib.optional (lib.hasPrefix "ext" config.fileSystems."/".fsType) pkgs.e2fsprogs;
        };
        availableKernelModules = lib.optional (config.fileSystems."/".fsType == "ext4") "ext4"; # Not automatically added because systemd-boot is "disabled"
      };
      lanzaboote = {
        enable = lib.mkDefault true;
        pkiBundle = lib.mkDefault "/var/lib/sbctl";
        autoGenerateKeys.enable = lib.mkDefault true;
        autoEnrollKeys = {
          enable = lib.mkDefault true;
          autoReboot = lib.mkDefault true;
        };
      };
      loader = {
        grub.enable = false;
        systemd-boot.enable = lib.mkForce false;
        efi.canTouchEfiVariables = lib.mkDefault true;
      };
    };
    system.fsPackages = lib.optional (lib.hasPrefix "ext"
      config.fileSystems."/".fsType
    ) pkgs.e2fsprogs; # Not automatically added because systemd-boot is "disabled"
  };
}

{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.sbfde.secureboot;
in
{
  options.sbfde.secureboot = {
    enable = lib.mkEnableOption "SecureBoot profile";
  };
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  config = lib.mkIf cfg.enable {
    boot = {
      initrd = {
        systemd = {
          tpm2.enable = true;
          initrdBin = lib.optional (lib.hasPrefix "ext" config.fileSystems."/".fsType) pkgs.e2fsprogs;
        };
        availableKernelModules = lib.optional (config.fileSystems."/".fsType == "ext4") "ext4"; # Not automatically added because systemd-boot is "disabled"
      };
      lanzaboote = {
        enable = true;
        pkiBundle = lib.mkDefault "/var/lib/sbctl";
      };
      loader = {
        grub.enable = false;
        systemd-boot.enable = lib.mkForce false;
        efi.canTouchEfiVariables = true;
      };
    };
    system.fsPackages = lib.optional (lib.hasPrefix "ext"
      config.fileSystems."/".fsType
    ) pkgs.e2fsprogs; # Not automatically added because systemd-boot is "disabled"
  };
}

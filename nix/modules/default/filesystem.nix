{
  pkgs,
  lib,
  config,
  utils,
  ...
}:
let
  cfg = config.sbfde;
in
{
  options.sbfde = {
    repartDefinitions = lib.mkOption {
      description = "The repart definition files";
      type = lib.types.package;
      readOnly = true;
      default = utils.systemdUtils.lib.definitions "repart.d" (pkgs.formats.ini {
        listsAsDuplicateKeys = true;
      }) (lib.mapAttrs (_n: v: { Partition = v; }) config.systemd.repart.partitions);
    };
  };
  config = lib.mkIf cfg.enable {
    boot.initrd.systemd.root = "gpt-auto";
    assertions = [
      {
        assertion = builtins.hasAttr "UUID" config.systemd.repart.partitions."10-esp";
        message = "No UUID specified for the EFI system partition. Generate one with `uuidgen`, then configure it on `systemd.repart.partitions.\"10-esp\".UUID`";
      }
      {
        assertion = builtins.hasAttr "UUID" config.systemd.repart.partitions."20-root";
        message = "No UUID specified for the root partition. Generate one with `uuidgen`, then configure it on `systemd.repart.partitions.\"20-root\".UUID`";
      }
    ];
    systemd.repart.partitions = {
      "10-esp" = rec {
        Type = "esp";
        Format = lib.mkDefault "vfat";
        Label = lib.mkDefault "ESP";
        # Careful with the min size: https://github.com/systemd/systemd/issues/37801
        SizeMinBytes = lib.mkDefault "1G";
        SizeMaxBytes = SizeMinBytes;
      };
      "20-root" = {
        Type = "root";
        Format = lib.mkDefault "ext4";
        Label = lib.mkDefault "nixos-encrypted";
        Encrypt = lib.mkDefault "key-file";
      };
    };
    fileSystems = {
      "/" = {
        fsType = lib.mkDefault config.systemd.repart.partitions."20-root".Format;
        device = "/dev/mapper/${config.fileSystems."/".encrypted.label}";
        encrypted = {
          enable = lib.mkDefault (
            !(builtins.elem config.systemd.repart.partitions."20-root".Encrypt [
              "off"
              false
            ])
          );
          blkDev = lib.mkDefault "PARTUUID=${config.systemd.repart.partitions."20-root".UUID}";
          label = lib.mkDefault "nixos";
        };
      };
      "/boot" = {
        fsType = lib.mkDefault config.systemd.repart.partitions."10-esp".Format;
        device = lib.mkDefault "PARTUUID=${config.systemd.repart.partitions."10-esp".UUID}";
        options = [
          "fmask=0022"
          "dmask=0022"
        ];
      };
    };
  };
}

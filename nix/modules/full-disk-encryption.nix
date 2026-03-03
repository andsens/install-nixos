{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.sbfde.full-disk-encryption;
  cryptenroll-tpm2 = pkgs.writeShellScriptBin "cryptenroll-tpm2" ''
    main() {
      local args=(
        --tpm2-device=auto --wipe-slot=tpm2
        --tpm2-pcrs=${cfg.tpm2PCRs}
        ${config.fileSystems."/".encrypted.blkDev}
      )
      [[ ! -e "${cfg.recoveryKeyPath}" ]] || args+=(--unlock-key-file "${cfg.recoveryKeyPath}")
      exec ${lib.getExe' pkgs.systemd "systemd-cryptenroll"} "''${args[@]}"
    }
    main "$@"
  '';
in
{
  options.sbfde.full-disk-encryption = {
    enable = lib.mkEnableOption "full disk encryption profile";
    recoveryKeyPath = lib.mkOption {
      description = "Location of the full disk encryption recovery key";
      type = lib.types.str;
      default = "/etc/cryptsetup-keys.d/nixos.key";
    };
    tpm2PCRs = lib.mkOption {
      description = "Which PCRs to lock the TPM2 key with";
      type = lib.types.str;
      default = "0+2+7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.lanzaboote.enable;
        message = "Full disk encryption relies on SecureBoot with lanzaboote, please enable it by including the secureboot profile";
      }
    ];
    fileSystems."/" = {
      fsType = lib.mkDefault "ext4";
      device = "/dev/mapper/${config.fileSystem."/".encrypted.label}";
      encrypted = {
        enable = true;
        blkDev = lib.mkDefault "/dev/disk/by-label/nixos-encrypted";
        label = lib.mkDefault "nixos";
      };
    };
    boot.initrd.luks.devices.nixos.crypttabExtraOpts = [
      "tpm2-measure-pcr=yes" # sooooper important, otherwise the key is accessible after booting
      "tpm2-device=auto"
    ];
    environment.systemPackages = [ cryptenroll-tpm2 ];
    systemd.services = {
      cryptenroll-tpm2 = lib.mkIf config.boot.lanzaboote.enable {
        restartIfChanged = true;
        description = "Enroll the TPM2 PCR for unlocking the root disk";
        unitConfig = {
          ConditionSecurity = [ "uefi-secureboot" ];
          ConditionPathExists = cfg.recoveryKeyPath;
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe cryptenroll-tpm2;
        };
        wantedBy = [ "default.target" ];
      };
      cryptenroll-wipe-empty = {
        restartIfChanged = false;
        stopIfChanged = false;
        description = "Remove the empty password that can unlock the root disk";
        after = [ "cryptenroll-tpm2.service" ]; # Prevent concurrent updates
        unitConfig = {
          FailureAction = "halt-force"; # It's critical that this is removed, don't let a system be used with this in place
          # Though, don't remove it before we have set up secureboot so the user doesn't have to enter a password
          ConditionSecurity = [ "uefi-secureboot" ];
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' pkgs.systemd "systemd-cryptenroll"} --wipe-slot=empty ${
            config.fileSystems."/".encrypted.blkDev
          }";
        };
        wantedBy = [ "default.target" ];
      };
    };
  };
}

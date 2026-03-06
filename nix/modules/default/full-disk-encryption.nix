{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.sbfde;
in
{
  options.sbfde = {
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
    enrollEmptyKey = lib.mkEnableOption "enrollment of an empty encryption key (eases setup procedure, will be removed after enrollment of the SecureBoot LUKS key)";
    enrollFallbackPassword = lib.mkEnableOption "enrollment of a fallback password";
  };
  config = lib.mkIf (cfg.enable && config.fileSystems."/".encrypted.enable) {
    systemd.services = {
      cryptenroll-tpm2 = lib.mkIf config.boot.lanzaboote.enable {
        restartIfChanged = true;
        description = "Enroll the TPM2 PCR for unlocking the root disk";
        unitConfig = {
          ConditionSecurity = [ "uefi-secureboot" ];
          ConditionPathExists = cfg.recoveryKeyPath;
        };
        serviceConfig.Type = "oneshot";
        script = ''
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
        wantedBy = [ "default.target" ];
      };
      cryptenroll-wipe-empty = lib.mkIf cfg.enrollEmptyKey {
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

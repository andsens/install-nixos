{ self, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.sbfde.installer;
in
{
  options.sbfde.installer = {
    enable = lib.mkEnableOption "installer ISO profile";
    repoUrl = lib.mkOption {
      description = "URL of the installation repository";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    deployKey = lib.mkOption {
      description = "SSH private key that can access the installation repository";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    knownHosts = lib.mkOption {
      description = "Lines of known_hosts to add to the SSH configuration";
      type = lib.types.nullOr lib.types.lines;
      default = null;
    };
    isoNixOSConfigurationName = lib.mkOption {
      description = "Name of the nixosConfiguration that configures the ISO installer, a shorthand for replacing \${config.networking.hostName} in updateUrl";
      type = lib.types.nullOr lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "\${config.networking.hostName}";
    };
    updateUrl = lib.mkOption {
      description = "Repourl & path to the installer package so it can run the newest version, null to disable";
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.repoUrl}#nixosConfigurations.${cfg.isoNixOSConfigurationName}.config.sbfde.installer.package";
      defaultText = lib.literalExpression "\${repoUrl}#nixosConfigurations.\${config.sbfde.installer.isoNixOSConfigurationName}.config.sbfde.installer.package";
    };
    unattended = {
      enable = lib.mkEnableOption "unattended installation";
      installDev = lib.mkOption {
        description = "The devicepath to install NixOS to";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      nixOSConfig = lib.mkOption {
        description = "The nixOS configuration to install";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      hashedPassword = lib.mkOption {
        description = "Hashed password of the primary user";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
    package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "installer" {
      extraDescription = "The installer package to use";
    };
    isoImage = lib.mkOption {
      description = "The installer ISO derivation";
      type = lib.types.package;
      readOnly = true;
      default = config.system.build.isoImage;
    };
    configuration = lib.mkOption {
      description = "The installer configuration file. Setting this option causes all other installer configs to be ignored.";
      type = lib.types.package;
      default = pkgs.stdenv.mkDerivation {
        name = "install-nixos";
        dontUnpack = true;
        # Would love for a builtins.toJSONPretty(data, indentChar)
        installPhase = ''
          runHook preInstall
          ${lib.getExe pkgs.jq} . >"$out" <<'EOF'
          ${builtins.toJSON (
            builtins.removeAttrs cfg [
              "enable"
              "deployKey"
              "knownHosts"
              "isoNixOSConfigurationName"
              "package"
              "isoImage"
              "includeConfiguration"
              "configuration"
            ]
          )}
          EOF
          runHook postInstall
        '';
      };
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      pkgs.sbctl
      pkgs.jq
      pkgs.iproute2
    ];
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    isoImage.contents = [
      {
        source = cfg.configuration;
        target = "config.json";
      }
    ]
    ++ (lib.optional (cfg.deployKey != null) {
      source = pkgs.writeText "deploy_key" cfg.deployKey;
      target = "deploy_key";
    })
    ++ (lib.optional (cfg.knownHosts != null) {
      source = pkgs.writeText "known_hosts" cfg.knownHosts;
      target = "known_hosts";
    });
    systemd.tmpfiles.settings."50-ssh" = {
      "/root/.ssh".d = {
        user = "root";
        group = "root";
        mode = "0700";
      };
      "/root/.ssh".f = {
        user = "root";
        group = "root";
        mode = "0600";
        argument = ''
          UserKnownHostsFile /iso/known_hosts
          IdentityFile %d/.ssh/deploykey
        '';
      };
    };
    security.sudo.extraConfig = ''
      # Keep install-nixos env vars for root and %wheel.
      Defaults:root,%wheel env_keep+=REPOURL
      Defaults:root,%wheel env_keep+=UPDATEURL
    '';
    environment.interactiveShellInit = ''
      if [[ $USER = nixos && ! -e .installer-launched ]]; then
        touch .installer-launched
        sudo install-nixos --abort-msg --auto-reboot
      fi
    '';
  };
}

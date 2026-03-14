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
    repo.url = lib.mkOption {
      description = "URL of the installation repository";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    repo.deploy-key = lib.mkOption {
      description = "SSH private key that can access the installation repository";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    known_hosts = lib.mkOption {
      description = "Lines of known_hosts to add to the installer ISO SSH configuration, enables strict host key checking";
      type = lib.types.nullOr lib.types.lines;
      default = null;
    };
    package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "installer" {
      extraDescription = "The installer package to use";
    };
    isoNixOSConfigurationName = lib.mkOption {
      description = "Name of the nixosConfiguration that configures the ISO installer, a shorthand for replacing $HOSTNAME \${config.networking.hostName} in update-url";
      type = lib.types.nullOr lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "\${config.networking.hostName}";
    };
    update-url = lib.mkOption {
      description = "Repourl & path to the installer package so it can run the newest version, null to disable";
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.repo.url}#nixosConfigurations.${cfg.isoNixOSConfigurationName}.config.sbfde.installer.package";
      defaultText = lib.literalExpression "\${repo.url}#nixosConfigurations.\${config.sbfde.installer.isoNixOSConfigurationName}.config.sbfde.installer.package";
    };
    unattended = {
      enable = lib.mkEnableOption "unattended installation";
      installDev = lib.mkOption {
        description = "The devicepath to install NixOS to";
        type = lib.types.str;
      };
      nixOSConfig = lib.mkOption {
        description = "The nixOS configuration to install";
        type = lib.types.str;
      };
      hashedPassword = lib.mkOption {
        description = "Hashed password of the primary user";
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
    iso-image = lib.mkOption {
      description = "The installer ISO derivation";
      type = lib.types.package;
      readOnly = true;
      default = config.system.build.isoImage;
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
    isoImage.contents = lib.optional cfg.unattended.enable {
      source = pkgs.writeText "unattended.json" (
        builtins.toJSON {
          installDev = cfg.unattended.installDev;
          nixOSConfig = cfg.unattended.nixOSConfig;
          hashedPassword = cfg.unattended.hashedPassword;
        }
      );
      target = "unattended.json";
    };
    programs.ssh = {
      knownHostsFiles = lib.optional (cfg.known_hosts != null) (
        pkgs.writeText "known_hosts" cfg.known_hosts
      );
      extraConfig = lib.join "\n" (
        (lib.optional (cfg.known_hosts != null) "StrictHostKeyChecking yes")
        ++ (lib.optional (cfg.repo.deploy-key != null) "IdentityFile %d/.ssh/deploykey")
      );
    };
    systemd.tmpfiles.settings."50-deploykey" = lib.mkIf (cfg.repo.deploy-key != null) {
      "/root/.ssh".d = {
        user = "root";
        group = "root";
        mode = "0700";
      };
      "/root/.ssh/deploykey"."f+" = {
        user = "root";
        group = "root";
        mode = "0600";
        argument = cfg.repo.deploy-key;
      };
      "/home/nixos/.ssh".d = {
        user = "nixos";
        group = "users";
        mode = "0700";
      };
      "/home/nixos/.ssh/deploykey"."f+" = {
        user = "nixos";
        group = "users";
        mode = "0600";
        argument = cfg.repo.deploy-key;
      };
    };
    security.sudo.extraConfig = ''
      # Keep install-nixos env vars for root and %wheel.
      Defaults:root,%wheel env_keep+=REPOURL
      Defaults:root,%wheel env_keep+=UPDATEURL
    '';
    environment.interactiveShellInit =
      if (cfg.repo.url != null) then
        let
          args = [
            "--abort-msg"
            "--auto-reboot"
            "--unattended"
          ];
        in
        ''
          export REPOURL=${cfg.repo.url}${
            lib.optionalString (cfg.update-url != null) "\nexport UPDATEURL=${cfg.update-url}"
          }
          if [[ $USER = nixos && ! -e .installer-launched ]]; then
            touch .installer-launched
            sudo install-nixos ${lib.escapeShellArgs args}
          fi
        ''
      else
        ''
          printf 'You can install NixOS by running `sudo install-nixos --repourl <FLAKE URL>`\n' >&2
        '';
  };
}

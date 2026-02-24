{ self, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.install-nixos;
in
{
  options.install-nixos = {
    repo.url = lib.mkOption {
      description = "URL of the installation repository";
      type = lib.types.str;
      default = null;
    };
    repo.deploy-key = lib.mkOption {
      description = "SSH private key that can access the installation repository";
      type = lib.types.str;
      default = null;
    };
    known_hosts = lib.mkOption {
      description = "Lines of known_hosts to add to the installer ISO SSH configuration, enables strict host key checking";
      type = lib.types.lines;
      default = null;
    };
    package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "install-nixos" {
      extraDescription = "The `install-nixos` package to use";
    };
    self-update-url = lib.mkOption {
      description = "URL to the installer package (\${config.install-nixos.package}) so it can run the newest version, null to disable";
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.repo.url}#nixosConfigurations.${config.networking.hostName}.config.install-nixos.package";
      defaultText = lib.literalExpression "\${repo.url}#nixosConfigurations.$HOSTNAME.config.install-nixos.package";
    };
    iso-image = lib.mkOption {
      description = ''The installer ISO derivation'';
      type = lib.types.package;
      readOnly = true;
      default = config.system.build.isoImage;
    };
  };
  imports = [ ./iso.nix ];
}

{ self, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
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
    iso-image = lib.mkOption {
      description = ''The installer ISO derivation'';
      type = lib.types.package;
      readOnly = true;
      default = config.system.build.isoImage;
    };
  };
  imports = [ ./iso.nix ];
}

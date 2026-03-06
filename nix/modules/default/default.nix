{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
with builtins;
let
  users = lib.sortOn (u: u.uid) (
    filter (u: u.enable && u.isNormalUser && u.uid != null && u.uid >= 1000) (
      attrValues config.users.users
    )
  );
  primaryUserHashedPasswordFile =
    if users == [ ] then null else lib.attrByPath [ "hashedPasswordFile" ] null (head users);
in
{
  options.sbfde = {
    enable = lib.mkEnableOption "SecureBoot Full Disk Encryption";
    includeInSelection = lib.mkOption {
      description = "Whether to include this host configuration in the installer prompt";
      type = lib.types.bool;
      default = false;
    };
    hashedPasswordFile = lib.mkOption {
      description = "Where to place the hashed password for the primary user of the system. `null` to disable the prompt.";
      type = lib.types.nullOr lib.types.str;
      default = primaryUserHashedPasswordFile;
      defaultText = "`hashedPasswordFile` of the first normal, enabled user with UID >= 1000";
    };
  };

  imports = [
    ./filesystem.nix
    ./full-disk-encryption.nix
    ./secureboot.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];
}

{
  description = "NixOS SecureBoot FDE";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      systems,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        config,
        self,
        ...
      }@mkFlakeArgs:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        systems = import systems;
        flake.nixosModules = {
          installer = args: { imports = [ (importApply ./nix/modules/installer.nix mkFlakeArgs) ]; };
          full-disk-encryption = args: { imports = [ ./nix/modules/full-disk-encryption.nix ]; };
          secureboot = args: { imports = [ ./nix/modules/secureboot.nix ]; };
        };
        perSystem =
          { pkgs, ... }:
          {
            packages.installer = pkgs.callPackage ./nix/installer { };
          };
      }
    );
}

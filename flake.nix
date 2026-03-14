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
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, self, ... }@mkFlakeArgs:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        systems = import systems;
        flake = {
          nixosModules = {
            default = args: { imports = [ (importApply ./nix/modules/default mkFlakeArgs) ]; };
            installer = args: { imports = [ (importApply ./nix/modules/installer mkFlakeArgs) ]; };
          };
          nixosConfigurations = {
            iso = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs self; };
              modules = [
                ./nix/configurations/iso.nix
                { networking.hostName = "nixos"; }
              ];
            };
          };
        };
        perSystem =
          { pkgs, ... }:
          {
            packages.installer = pkgs.callPackage ./nix/installer { };
          };
      }
    );
}

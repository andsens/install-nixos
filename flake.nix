{
  description = "home-server";
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
    { systems, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, self, ... }@mkFlakeArgs:
      {
        systems = import systems;
        flake.nixosModules = {
          default = config.flake.nixosModules.install-nixos;
          install-nixos =
            { pkgs, lib, ... }@args:
            {
              imports = [ ((import ./nix mkFlakeArgs) args) ];
            };
        };
        perSystem =
          { pkgs, ... }:
          {
            packages.install-nixos = pkgs.callPackage ./nix/installer.nix { };
          };
      }
    );
}

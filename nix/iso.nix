{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.install-nixos;
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];
  environment.systemPackages = [
    cfg.package
    pkgs.sbctl
    pkgs.jq
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
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
  environment.interactiveShellInit =
    if (cfg.repo.url != null) then
      let
        args = [
          "--abort-msg"
          "--auto-reboot"
        ]
        ++ lib.optional (cfg.self-update-url != null) "--update=${cfg.self-update-url}";
      in
      ''
        export REPOURL=${cfg.repo.url}
        if [[ $USER = nixos && ! -e .installer-launched ]]; then
          touch .installer-launched
          sudo install-nixos ${lib.escapeShellArgs args}
        fi
      ''
    else
      ''
        printf 'You can install NixOS by running `sudo install-nixos --repourl <FLAKE URL>`\n' >&2
      '';
}

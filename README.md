# nixos-sbfde

Flake modules for configuring and installing NixOS with SecureBoot-backed
full disk encryption.  
The installer sets up full disk encryption with automatic unlocking using
secure boot.  
There is a menu for selecting the disk, host configuration, user password,
disk encryption fallback password, and the boot partition size.

# Setup

Add `nixos-sbfde` to your `flake.nix`:

```nix
{
  inputs = {
    ...
    nixos-sbfde = {
      url = "github:andsens/nixos-sbfde";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ...
  };
  ...
}
```

## Host configuration

Import the default module in your `configuration.nix`, enable it, and mark your
config to be included in the installation prompt:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-sbfde.nixosModules.default
 ];
  config = {
    sbfde.enable = true;
    sbfde.includeInSelection = true;
  };
```

## Installer

Create a `configuration.nix` for your installation USB stick:

```nix
{ inputs, modulesPath, ... }:
{
  imports = [
    inputs.nixos-sbfde.nixosModules.installer
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];
  config = {
    system.stateVersion = "25.11";
    time.timeZone = "Europe/Copenhagen";
    nixpkgs.hostPlatform = "x86_64-linux";
    networking.hostName = "installer";
    sbfde.installer = {
      enable = true;
      # Can be omitted
      repo.url = "git+ssh://git@github.com/username/reponame";
      # If your repo is public you won't need this option
      repo.deploy-key = ''
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
        QyNTUxOQAAACBu7idAKt8F/rwv6TnFVDKnpDFlPIwHu08umgyYHGmX5AAAAJDpO/ef6Tv3
        nwAAAAtzc2gtZWQyNTUxOQAAACBu7idAKt8F/rwv6TnFVDKnpDFlPIwHu08umgyYHGmX5A
        AAAEB2njRY4SB8Tcy+pBfUQCdy7YjzXSGFdoBYQDIpvq6zdG7uJ0Aq3wX+vC/pOcVUMqek
        MWU8jAe7Ty6aDJgcaZfkAAAADWluc3RhbGwtbml4b3M=
        -----END OPENSSH PRIVATE KEY-----
      '';
      # Use `ssh-keyscan github.com | grep -v '^#'` to generate these lines, leave out to disable strict host key checking
      known_hosts = ''
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      '';
    };
  };
}
```

Add it to your `flake.nix`:

```nix
{
  ...
  outputs = {
    ...
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs lib; };
      modules = [ ./hosts/installer/configuration.nix ];
    };
    ...
  };
  ...
}
```

# Building

To build an ISO that you can put on a USB stick, run:

```
nix build '.#nixosConfigurations.installer.config.sbfde.installer.iso-image'
```

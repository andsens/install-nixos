{
  lib,
  bash,
  jq,
  git,
  curl,
  util-linux,
  dialog,
  parted,
  coreutils,
  gettext,
  su,
  sbctl,
  openssh,
  ncurses,
  nix,
  systemd,
  dosfstools,
  e2fsprogs,
  nixos-install,
  gnugrep,
  shadow,
  cryptsetup,
  stdenv,
  fetchzip,
  ...
}:
let
  records_sh = fetchzip {
    name = "records.sh";
    version = "1.0.3";
    url = "https://github.com/orbit-online/records.sh/releases/download/v1.0.3/records.sh.tar.gz";
    hash = "sha256-A3d3OolMGOv08PqdxzUbx65Y3lIpmonns4xzg+kuW9k=";
    stripRoot = false;
  };
  docopt_sh = fetchzip {
    name = "docopt.sh";
    version = "2.0.3";
    url = "https://github.com/andsens/docopt.sh/releases/download/v2.0.3/docopt-lib.sh.tar.gz";
    hash = "sha256-L0J6aFgEcPPJnoJD6oZwtnAzGIB1R5cdZz6R7Ez5zcc=";
    stripRoot = false;
  };
in
stdenv.mkDerivation rec {
  name = "install-nixos";
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cat >"$out/bin/${name}" <<EOF
    #!${lib.getExe bash}
    export PATH="${
      lib.makeBinPath [
        bash
        jq
        git
        curl
        util-linux
        dialog
        parted
        coreutils
        gettext
        su
        sbctl
        openssh
        ncurses
        nix
        systemd
        dosfstools
        e2fsprogs
        nixos-install
        gnugrep
        shadow
        cryptsetup
      ]
    }" \\
    RECORDS_SH=${records_sh} \\
    DOCOPT_LIB_SH=${docopt_sh} \\
    REPART_D=${./repart.d}
    exec ${./installer} "\$@"
    EOF
    chmod +x "$out/bin/${name}"
    runHook postInstall
  '';

  meta = with lib; {
    description = "NixOS Installation Utility";
    homepage = "https://github.com/andsens/install-nixos";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ sgo ];
    mainProgram = name;
  };
}

{ pkgs ? import <nixpkgs> {} }:
let
  stdenv = pkgs.stdenv;

  version = "6967";

  openssl_1_0_2 = stdenv.mkDerivation {
    name = "openssl_1_0_2";
    builder = pkgs.writeText "builder.sh" ''
      . $stdenv/setup
      base=${pkgs.openssl.out}
      mkdir -p $out/lib
      ln -sf $base/etc $out
      ln -sf $base/lib/* $out/lib
      ln -sf $base/lib/libssl.so.1.0.0 $out/lib/libssl.so.1.0.2
      ln -sf $base/lib/libcrypto.so.1.0.0 $out/lib/libcrypto.so.1.0.2
    '';
    buildInputs = [ pkgs.openssl ];
  };

  sky-deb = stdenv.mkDerivation {
    name = "sky-deb-${version}";
    builder = pkgs.writeText "builder.sh" ''
      . $stdenv/setup
      PATH=${pkgs.dpkg}/bin:$PATH
      dpkg -x $src unpack
      cp -r unpack/* $out
    '';
    src = pkgs.fetchurl {
      url = "https://tel.red/linux.php?f=sky_2.1.6967-1ubuntu%2Byakkety_amd64.deb";
      name = "sky_2.1.6967-debian_amd64.deb";
      sha256 = "08kk0nlid2iga2mvyjdzv9rbp9g3q23jrl17mcpfri2p9474fjmp";
    };
  };
in rec {
  sky = pkgs.buildFHSUserEnv {
    name = "sky";
    targetPkgs = pkgs: [
      sky-deb
      openssl_1_0_2
      pkgs.xorg.libX11
      pkgs.xorg.libXScrnSaver
      pkgs.xorg.libxkbfile
      pkgs.xorg.libXmu
      pkgs.xorg.libXinerama
      pkgs.xorg.libXcursor
      pkgs.xorg.libXtst
      pkgs.xorg.libXrandr
      pkgs.xorg.libXv
      pkgs.xorg.libXi
      pkgs.xorg.libXrender
      pkgs.xorg.libXdamage
      pkgs.xorg.libXfixes
      pkgs.qt56.full
      pkgs.libv4l
      pkgs.libuuid
      pkgs.curl
      pkgs.ffmpeg
      pkgs.libpulseaudio
      pkgs.sqlite
      pkgs.libjpeg_original
      pkgs.alsaLib
      pkgs.procps
      pkgs.bash
      pkgs.coreutils
    ];
    runScript = "sky";
  };
}

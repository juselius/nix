let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "6997";

  # openssl_1_0_2 = stdenv.mkDerivation {
  #   name = "openssl_1_0_2";
  #   builder = pkgs.writeText "builder.sh" ''
  #     . $stdenv/setup
  #     base=${pkgs.openssl.out}
  #     mkdir -p $out/lib
  #     ln -sf $base/etc $out
  #     ln -sf $base/lib/* $out/lib
  #     ln -sf $base/lib/libssl.so.1.0.0 $out/lib/libssl.so.1.0.2
  #     ln -sf $base/lib/libcrypto.so.1.0.0 $out/lib/libcrypto.so.1.0.2
  #   '';
  #   buildInputs = [ pkgs.openssl ];
  # };

  rpath = with pkgs; stdenv.lib.makeLibraryPath [
    # pkgs.fuse
    # pkgs.glib
    # pkgs.zlib
    openssl
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libxkbfile
    xorg.libXmu
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXtst
    xorg.libXrandr
    xorg.libXv
    xorg.libXi
    xorg.libXrender
    xorg.libXdamage
    xorg.libXfixes
    qt56.full
    libv4l
    libuuid
    curl
    ffmpeg
    libpulseaudio
    sqlite
    libjpeg_original
    alsaLib
    procps
    bash
    coreutils
  ];

  src = pkgs.fetchurl {
    url = "https://tel.red/linux.php?f=sky_2.1.6997-1ubuntu%2Byakkety_amd64.deb";
    name = "sky_2.1.6997-debian_amd64.deb";
    sha256 = "1mqvzvk06mqc9fli9mzb97p45dil98k11wzpqn4pjk2wibw3g9aw";
  };

in
  stdenv.mkDerivation {
    name = "sky-${version}";
    inherit src;
    buildCommand = ''
      . $stdenv/setup

      PATH=${pkgs.dpkg}/bin:$PATH
      dpkg -x $src unpack
      cp -r unpack/* $out

      ln -s ${stdenv.cc.cc.lib.outPath}/lib/libstdc++.so.6 $out/lib/sky/lib64

      cd $out/lib/sky
      for i in sky sky_sender lib64/*; do
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $i || true
        patchelf --set-rpath ${rpath}:$out/lib/sky/lib64 $i || true
      done
      for i in $(find -name \*.sh); do
        substituteInPlace $i --replace "/bin/bash" "/usr/bin/env bash"
      done
    '';
  }

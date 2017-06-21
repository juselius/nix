let pkgs = import <nixpkgs> {};
    stdenv = pkgs.stdenv;
in rec {
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
  telred-sky-deb = stdenv.mkDerivation {
    name = "telred-sky-deb";
    builder = pkgs.writeText "builder.sh" ''
      . $stdenv/setup
      PATH=${pkgs.dpkg}/bin:$PATH
      dpkg -x $src unpack
      cp -r unpack/* $out
    '';
    src = pkgs.fetchurl {
      url = "https://tel.red/linux.php?f=sky_2.1.6706-2debian%2Bstretch_amd64.deb";
      name = "sky_2.1.6702-2debian_amd64.deb";
      sha256 = "14l2m300bnz0lcl0fhssc8g8179h5p459jrq2xp09ssp08ilaabl";
    };
  };
  telred-sky = pkgs.buildFHSUserEnv {
    name = "telred-sky";
    targetPkgs = pkgs: [
      telred-sky-deb
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
      pkgs.qt5.full
      pkgs.libv4l
      pkgs.libuuid
      pkgs.curl
      pkgs.ffmpeg
      pkgs.libpulseaudio
      pkgs.sqlite
      pkgs.libjpeg
      pkgs.alsaLib
      pkgs.procps
      pkgs.bash
      pkgs.coreutils
    ];
    runScript = "sky";
  };
}

let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "2.1.6940";

  rpath = stdenv.lib.makeLibraryPath [
      openssl_1_0_2
      libstdcxx6
      libjpeg8
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
      pkgs.qt5.qtbase
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
      pkgs.libstdcxx5
      pkgs.gcc
  ];

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

  libstdcxx6 = stdenv.mkDerivation {
    name = "libstdcxx6";
    builder = pkgs.writeText "builder.sh" ''
      . $stdenv/setup
      base=${stdenv.cc.cc.lib.outPath}
      mkdir -p $out/lib
      ln -sf $base/lib/libstdc++.so.6 $out/lib
    '';
    buildInputs = [ pkgs.gcc ];
  };

  libjpeg8 = stdenv.mkDerivation {
    name = "libjpeg8";
    builder = pkgs.writeText "builder.sh" ''
      . $stdenv/setup
      base=${pkgs.libjpeg.out.outPath}
      mkdir -p $out/lib
      ln -sf $base/lib/libjpeg.so.62 $out/lib/libjpeg.so.8
    '';
    buildInputs = [ pkgs.libjpeg ];
  };

  src = pkgs.fetchurl {
    url = "https://tel.red/linux.php?f=sky_${version}-1ubuntu%2Bzesty_amd64.deb";
    name = "sky_${version}-ubuntu_zesty_amd64.deb";
    sha256 = "1fcwk5dhpgq1m1g04z212i6d6m9yxra1dxdswsmvs7xgwvdky4ip";
  };
in
  stdenv.mkDerivation {
    name = "sky-${version}";
    inherit src;
    buildInputs = [ pkgs.dpkg ];
    unpackPhase = "true";
    buildCommand = ''
      mkdir -p $out
      dpkg -x $src $out
      mv $out/usr/* $out
      rmdir $out/usr

      # Otherwise it looks "suspicious"
      chmod -R g-w $out

      for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* \) ); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$out/lib/sky/lib64 $file || true
      done

      # Fix the symlink
      rm $out/bin/sky
      ln -s $out/lib/sky/sky $out/bin/sky

      # Fix the desktop link
      substituteInPlace $out/share/applications/sky.desktop \
      --replace /usr/bin/ $out/bin/ \
      --replace /usr/share/ $out/share/
    '';

    meta = with stdenv.lib; {
      description = "Telred Skype for Business client";
      homepage = https://tel.red;
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
}

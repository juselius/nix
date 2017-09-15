let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "2.0";

  rpath = stdenv.lib.makeLibraryPath [
      libstdcxx6
      openssl_1_0_2
      pkgs.icu
      pkgs.libunwind
      pkgs.openssl
      pkgs.libuuid
      pkgs.zlib
      pkgs.libzip
      pkgs.curl
      pkgs.mono
  ];
  openssl_1_0_2 = stdenv.mkDerivation {
    name = "openssl_1_0_2";
    buildCommand = ''
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
    buildCommand = ''
      . $stdenv/setup
      base=${stdenv.cc.cc.lib.outPath}
      mkdir -p $out/lib
      ln -sf $base/lib/libstdc++.so.6 $out/lib
    '';
    buildInputs = [ pkgs.gcc ];
  };
  icu55 = stdenv.mkDerivation {
    name = "libicu55";
    buildCommand = ''
      . $stdenv/setup
      base=${pkgs.icu.out}
      mkdir -p $out/lib
      ln -sf $base/lib/* $out/lib
      for i in $out/lib/lib*.so; do
        ln -sf $i $i.55
      done
    '';
    buildInputs = [ pkgs.icu ];
  };
  src = pkgs.fetchurl {
    url = "https://dot.net/v1/dotnet-install.sh";
    sha256 = "01nxkndm2n8vn33rvj9fb907qp676b9r53zyz2j1kj5m2r0j4bnw";
  };

in rec {
  dotnet-core-sdk = stdenv.mkDerivation {
    name = "dotnet-core-sdk-${version}";
    inherit src;
    buildCommand = ''
      . $stdenv/setup

      instdir=$out/libexec/dotnet-${version}
      mkdir -p $instdir
      mkdir -p $out/bin

      sed '/\[ -z "\$(\$LDCONFIG_COMMAND/d; s/curl --retry 10/curl --retry 10 -k/;' $src > dotnet-install.sh
      /bin/sh dotnet-install.sh -c 2.0 -i $instdir --verbose

      rpath=""
      rpath=$rpath:$instdir/host/fxr/2.0.0
      rpath=$rpath:$instdir/shared/Microsoft.NETCore.App/2.0.0

      for file in $instdir/dotnet $(find $instdir -type f -name \*.so ); do
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
        patchelf --set-rpath ${rpath}:$rpath $file || true
      done

      ln -s $instdir/dotnet $out/bin/dotnet
      # Otherwise it looks "suspicious"
      chmod -R g-w $out
    '';
    buildInputs = [
      pkgs.curl
      pkgs.mono
    ];
    meta = with stdenv.lib; {
      description = ".NET Core SDK";
      homepage = https://www.microsoft.com/net/core;
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
}

let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "1.0.4";

  rpath = stdenv.lib.makeLibraryPath [
      libstdcxx6
      openssl_1_0_2
      icu55
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
  icu55 = stdenv.mkDerivation {
    name = "libicu55";
    builder = pkgs.writeText "builder.sh" ''
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
  src = pkgs.fetchurl {
    url = "https://download.microsoft.com/download/E/7/8/E782433E-7737-4E6C-BFBF-290A0A81C3D7/dotnet-dev-ubuntu.16.04-x64.1.0.4.tar.gz";
    name = "dotnet-dev-ubuntu.16.04-x64.${version}.tar.gz";
    sha256 = "1dvakdwzhgfhc35wyxjvv8cvm1k43ms4jhl63y46bg80kdhfrd3g";
  };
in rec {
  dotnet-core-sdk = stdenv.mkDerivation {
    name = "dotnet-core-sdk-${version}";
    inherit src;
    # unpackPhase = "true";
    buildCommand = ''
      . $stdenv/setup

      instdir=$out/libexec/dotnet-${version}
      mkdir -p $instdir
      mkdir -p $out/bin

      cd $instdir
      tar vfxz $src

      # Otherwise it looks "suspicious"
      chmod -R g-w $out

      rpath=""
      rpath=$rpath:$out/host/fxr/1.0.1
      rpath=$rpath:$out/host/fxr/1.1.0
      rpath=$rpath:$out/sdk/1.0.4
      rpath=$rpath:$out/shared/Microsoft.NETCore.App/1.0.5
      rpath=$rpath:$out/shared/Microsoft.NETCore.App/1.1.2

      for file in $instdir/dotnet $(find $out -type f -name \*.so\* ); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$rpath $file || true
      done

      ln -s $instdir/dotnet $out/bin/dotnet
    '';
    meta = with stdenv.lib; {
      description = ".NET Core SDK";
      homepage = https://www.microsoft.com/net/core;
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
}

let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "1.0";

  rpath = stdenv.lib.makeLibraryPath [
      libstdcxx6
      pkgs.libuuid
      pkgs.unixODBC
  ];

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

  src = pkgs.fetchurl {
    url = "file:///home/jonas/src/nix/mssql/mssql-tools.tgz";
    sha256 = "1g20mba227r4nazhl165s6jiym8g3fhw5mmgwna2xf6ip6mc28yk";
  };
in rec {
  mssql-tools = stdenv.mkDerivation {
    name = "mssql-tools-${version}";
    inherit src;
    buildCommand = ''
      . $stdenv/setup

      instdir=$out/libexec/mssql-tools-${version}
      mkdir -p $instdir
      mkdir -p $out/bin

      tar vfxz $src
      cp -a mssql-tools/* $instdir

      for file in $instdir/bin/*; do
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
        patchelf --set-rpath ${rpath} $file || true
      done

      cat << EOF > $out/bin/sqlcmd
      #!/usr/bin/env bash
      exec $instdir/bin/sqlcmd
      EOF
      cat << EOF > $out/bin/bcp
      #!/usr/bin/env bash
      exec $instdir/bin/bcp
      EOF
      chmod 755 $out/bin/sqlcmd $out/bin/bcp
      # Otherwise it looks "suspicious"
      chmod -R g-w $out
    '';
    buildInputs = [
      pkgs.libuuid
      pkgs.unixODBC
    ];
    meta = with stdenv.lib; {
      description = "SQL Server 2017 CLI Tools";
      homepage = https://www.microsoft.com/;
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
}

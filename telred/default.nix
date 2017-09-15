let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  version = "2.1.6940";

  rpath = stdenv.lib.makeLibraryPath [
    pkgs.fuse
    pkgs.glib
    pkgs.zlib
  ];

  src = pkgs.fetchurl {
    url = "https://tel.red/linux/sky-latest-x86_64.AppImage";
    name = "sky_${version}-x86_64.AppImage";
    sha256 = "0g6223az7pjn717710bqcykx3ciz2gnzn933k8789kc9mb20vdw8";
  };
in
  stdenv.mkDerivation {
    name = "sky-${version}";
    inherit src;
    buildCommand = ''
      mkdir -p $out/bin
      file=$out/bin/sky
      cp $src $file
      chmod 755 $file
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $file || true
      patchelf --set-rpath ${rpath} $file || true
    '';

    meta = with stdenv.lib; {
      description = "Telred Skype for Business client";
      homepage = https://tel.red;
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
}

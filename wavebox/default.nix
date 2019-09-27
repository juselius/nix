with import <nixpkgs> {};
with pkgs.stdenv.lib;
let
  version = "4.11.3";
  tarball = "Wavebox_${replaceStrings ["."] ["_"] (toString version)}_linux_x86_64.tar.gz";
  desktopItem = makeDesktopItem rec {
    name = "Wavebox";
    exec = name;
    icon = "wavebox";
    desktopName = name;
    genericName = name;
    categories = "Network;";
  };
in
pkgs.wavebox.overrideAttrs (attrs: rec {
  name = "wavebox-${version}";
  src = pkgs.fetchurl {
    url = "https://github.com/wavebox/waveboxapp/releases/download/v${version}/${tarball}";
    sha256 = "0z04071lq9bfyrlg034fmvd4346swgfhxbmsnl12m7c2m2b9z784";
  };
  installPhase = ''
    mkdir -p $out/bin $out/opt/wavebox
    cp -r * $out/opt/wavebox

    # provide desktop item and icon
    mkdir -p $out/share/applications $out/share/pixmaps
    ln -s ${desktopItem}/share/applications/* $out/share/applications
    ln -s $out/opt/wavebox/wavebox_icon.png $out/share/pixmaps/wavebox.png
  '';
})

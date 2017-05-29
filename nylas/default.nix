let nixpkgs = import <nixpkgs> {};
    stdenv = nixpkgs.stdenv;
in rec {
  nylas-deb = stdenv.mkDerivation {
    name = "nylas-deb";
    builder = ./builder.sh;
    dpkg = nixpkgs.dpkg;
    src = nixpkgs.fetchurl {
      url = "https://edgehill.nylas.com/download?platform=linux-deb";
      sha256 = "1njamai7yr4m4g4c566zj6icbqr76kgbj1saxnw8fl9vvjhhl1j0";
    };
  };
  nylas = nixpkgs.buildFHSUserEnv {
    name = "nylas";
    targetPkgs = pkgs: [
      nylas-deb
      pkgs.gtk2-x11
      pkgs.atk
      pkgs.glib
      pkgs.pango
      pkgs.cairo
      pkgs.gdk_pixbuf
      pkgs.freetype
      pkgs.fontconfig
      pkgs.dbus
      pkgs.xorg.libXi
      pkgs.xorg.libXcursor
      pkgs.xorg.libXdamage
      pkgs.xorg.libXrandr
      pkgs.xorg.libXcomposite
      pkgs.xorg.libXext
      pkgs.xorg.libXfixes
      pkgs.xorg.libXrender
      pkgs.xorg.libX11
      pkgs.xorg.libXtst
      pkgs.xorg.libXScrnSaver
      pkgs.xorg.libXScrnSaver
      pkgs.xorg.libxkbfile
      pkgs.gnome2.GConf
      pkgs.libgnome_keyring
      pkgs.nss
      pkgs.nspr
      pkgs.alsaLib
      pkgs.cups
      pkgs.expat
      pkgs.wget
      pkgs.libudev
    ];
    multiPkgs = pkgs: [ pkgs.dpkg ];
    runScript = "nylas-mail";
  };
}

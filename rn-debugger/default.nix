with (import <nixpkgs> {});
let

  version = "0.7.18";
  version_ = builtins.replaceStrings [ "." ] [ "_" ] version;

  rpath = stdenv.lib.makeLibraryPath [
    alsaLib
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    glib
    gnome2.GConf
    gnome2.gdk_pixbuf
    gnome2.gtk
    gnome2.pango
    libnotify
    nspr
    nss
    stdenv.cc.cc
    systemd

    xorg.libxcb
    xorg.libxkbfile
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXScrnSaver
  ] + ":${stdenv.cc.cc.lib}/lib64";

  src =
    if stdenv.system == "x86_64-linux" then
      fetchurl {
        url = "https://github.com/jhen0409/react-native-debugger/releases/download/v${version}/rn-debugger-linux-x64.zip";
        sha256 = "186n438sy9wzrx2zdw4qq4hsz89wiy01bpfa6fdjisvxgz6r8sgw";
      }
    else
      throw "Wavebox is not supported on ${stdenv.system}";

in stdenv.mkDerivation {
  name = "rn-debuger-${version}";

  inherit src;

  unpackPhase = "true";
  buildCommand = ''
    instdir=$out/libexec/rn-debugger
    mkdir -p $instdir
    cd $instdir
    unzip $src
    mv React\ Native\ Debugger rn-debugger

    # Otherwise it looks "suspicious"
    chmod -R g-w $out

    lnkr=$(cat $NIX_CC/nix-support/dynamic-linker)

    for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* \) ); do
      echo "patchelf --set-interpreter $lnkr $file"
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$instdir $file || true
    done

    # Fix the symlink
    mkdir $out/bin
    ln -s $out/libexec/rn-debugger/rn-debugger $out/bin/rn-debugger
  '';

  buildInputs = [
    unzip
    # caladea
    # carlito
    # comic-relief
    # liberation_ttf
  ];

  meta = with stdenv.lib; {
    description = "React Native Debugger";
    homepage = https://github.com/jhen0409/react-native-debugger;
    license = licenses.free;
    platforms = [ "x86_64-linux" ];
  };
}

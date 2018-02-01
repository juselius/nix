with (import <nixpkgs> {});
let

  version = "3.9.0";

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
        url = "https://github.com/wavebox/waveboxapp/releases/download/v3.9.0/Wavebox_3_9_0_linux_x86_64.tar.gz";
        sha256 = "0rj61dnyrzh7lj4ibmphyp4ay5qfjqr9n62cgkdxcw2jhkw5jynx";
      }
    else
      throw "Wavebox is not supported on ${stdenv.system}";

in stdenv.mkDerivation {
  name = "wavebox-${version}";

  inherit src;

  unpackPhase = "true";
  buildCommand = ''
    instdir=$out/libexec
    mkdir -p $instdir
    cd $instdir
    tar vfxz $src
    mv Wavebox-linux-x64 Wavebox
    wavebox=$instdir/Wavebox
    chmod 644 $wavebox/wavebox_icon.png

    # Otherwise it looks "suspicious"
    chmod -R g-w $out

    for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* \) ); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$wavebox $file || true
    done

    # Fix the symlink
    mkdir $out/bin
    ln -s $out/libexec/Wavebox/Wavebox $out/bin/wavebox

    # Fix the desktop link
    mkdir -p $out/share/applications
    ln -s $wavebox/wavebox.desktop $out/share/applications/wavebox.desktop
    substituteInPlace $out/share/applications/wavebox.desktop \
      --replace /opt/wavebox/ $wavebox
  '';

  meta = with stdenv.lib; {
    description = "Wavebox";
    homepage = https://wavebox.io;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}

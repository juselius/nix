{ pkgs ? import <nixpkgs> {} }:
with pkgs;
pkgs.hplip.overrideAttrs (attrs: rec {
  postFixup = ''
    wrapProgram $out/lib/cups/filter/hpps \
      --prefix PATH : "${nettools}/bin" \
      --set PYTHONPATH "${hplip}/lib/python2.7/site-packages"

    substituteInPlace $out/etc/hp/hplip.conf --replace /usr $out
    # A udev rule to notify users that they need the binary plugin.
    # Needs a lot of patching but might save someone a bit of confusion:
    substituteInPlace $out/etc/udev/rules.d/56-hpmud.rules \
      --replace {,${bash}}/bin/sh \
      --replace {/usr,${coreutils}}/bin/nohup \
      --replace {,${utillinux}/bin/}logger \
      --replace {/usr,$out}/bin
  '';
})

with import <nixpkgs> {};
let
  version = "4.26.0";
  ver = "${version}-93";
  arch = "amd64";
  srcdir = "mft-${ver}-x86_64-deb";
  kernel = pkgs.linux.dev;

  rpath = lib.strings.concatStringsSep ":" [
    "${pkgs.libxcrypt}/lib"
    "${pkgs.glibc}/lib"
    "${stdenv.cc.cc.lib.outPath}/lib"
  ];

  mkmft = x: stdenv.mkDerivation {
    name = "mft${x}-${ver}";
    buildCommand = ''
      #!${pkgs.bash}/bin/bash
      source $stdenv/setup
      PATH=${pkgs.dpkg}/bin:$PATH
      dpkg -x $src $out
      for i in $out/usr/bin/*; do
         if $(file $i | grep -q 'ELF.*dynamic'); then
           patchelf \
             --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
             --set-rpath "${rpath}" $i
         elif $(file $i | grep -q shell); then
            patchShebangs --build $i
         fi
      done
    '';
    src = ./${srcdir}/DEBS/mft${x}_${ver}_${arch}.deb;
  };
in
{
  oem = mkmft "-oem";
  pcap = mkmft "-pcap";
  mft = mkmft "";

  mft-kernel-module = stdenv.mkDerivation {
    name = "mft-kernel-module";
    pname = "mft-kernel-module";

    src = ./${srcdir}/SDEBS/kernel-mft-dkms_${ver}_all.deb;

    unpackPhase = ''
      #!${pkgs.bash}/bin/bash
      source $stdenv/setup
      PATH=${pkgs.dpkg}/bin:$PATH
      dpkg -x $src $out
      export sourceRoot="$out/usr/src/kernel-mft-dkms-${version}";
      cd $out
    '';

    nativeBuildInputs = kernel.moduleBuildDependencies;

    makeFlags = kernel.makeFlags ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(sourceRoot)"
    ];

    buildFlags = [ "modules" ];
    installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];
    installTargets = [ "modules_install" ];

    meta = {
      description = "Mellanox MFT kernel module";
    };
  };
}

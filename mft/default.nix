with import <nixpkgs> {};
let
  version = "4.27.0";
  ver = "${version}-83";
  arch = "amd64";
  kernel = pkgs.linux.dev;

  rpath = lib.strings.concatStringsSep ":" [
    "${pkgs.libxcrypt}/lib"
    "${pkgs.glibc}/lib"
    "${stdenv.cc.cc.lib.outPath}/lib"
  ];

  src = pkgs.fetchurl {
    url = "https://www.mellanox.com/downloads/MFT/mft-${ver}-x86_64-deb.tgz";
    hash = "sha256-Mx2dyHSFkZ+vsorAd7yVe2vU8nhksoGieE+LPcA5fZA=";
  };

  unpackPhase = ''
      PATH=${pkgs.dpkg}/bin:$PATH
      tar vfxz $src
      mv mft-${ver}-x86_64-deb deb
  '';

  mkmft = x: stdenv.mkDerivation {
    name = "mft${x}-${ver}";
    inherit src;
    inherit unpackPhase;

    installPhase = ''
      PATH=/bin:$PATH
      dpkg -x deb/DEBS/mft${x}_${ver}_${arch}.deb $out
    '';

    preFixup = ''
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
  };
in
{
  oem = mkmft "-oem";
  pcap = mkmft "-pcap";
  mft = mkmft "";

  mft-kernel-module = stdenv.mkDerivation {
    name = "mft-kernel-module";
    pname = "mft-kernel-module";
    inherit src;
    inherit unpackPhase;

    prePatch = ''
      PATH=/bin:$PATH
      dpkg -x deb/SDEBS/kernel-mft-dkms_${ver}_all.deb source
    '';

    preConfigure = ''
      export KSRC="${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      export sourceRoot="/build/source/usr/src/kernel-mft-dkms-${version}"
      buildRoot () { echo $KSRC; }
    '';

    nativeBuildInputs = kernel.moduleBuildDependencies;

    buildPhase = ''
      cd $sourceRoot/mst_backward_compatibility/mst_pci
      make ${lib.strings.concatStringsSep " " kernel.makeFlags} -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" M=$(pwd) modules
      cd $sourceRoot/mst_backward_compatibility/mst_pciconf
      make ${lib.strings.concatStringsSep " " kernel.makeFlags} -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" M=$(pwd) modules
    '';

    installPhase = ''
      instdir=$out/lib/modules/${kernel.modDirVersion}/extras/mft
      mkdir -p $instdir
      cp $sourceRoot/mst_backward_compatibility/mst_pci/mst_pci.ko $instdir
      cp $sourceRoot/mst_backward_compatibility/mst_pciconf/mst_pciconf.ko $instdir
    '';

    meta = {
      description = "Mellanox MFT kernel module";
    };
  };
}

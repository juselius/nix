{pkgs, lib, stdenv, kernel ? pkgs.linux, ...}:
let
  version = "4.27.0";
  ver = "${version}-83";
  arch = "amd64";

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

in
rec {
  mft = stdenv.mkDerivation {
    name = "mft-${ver}";
    inherit src unpackPhase preFixup;

    installPhase = ''
      PATH=/bin:$PATH
      dpkg -x deb/DEBS/mft_${ver}_${arch}.deb $out
      rm $out/usr/bin/mst
      mv $out/etc/init.d/mst $out/usr/bin/mst
      rmdir $out/etc/init.d
      sed -i "s,/usr/mst,$out&,;
              s,/sbin/modprobe,${pkgs.kmod}&,;
              s,/sbin/lsmod,${pkgs.kmod}&,;
              s,=lspci,=${pkgs.pciutils}/bin/lspci,;
              s,mbindir=,&$out,;
              s,mlibdir=,&$out,;
              s,modprobe \+-r,rmmod,;
              s,MST_PCI_MOD=.*,MST_PCI_MOD="${mft-kernel-module}/lib/modules/${kernel.version}/extras/mft/mst_pci.ko,";
              s,MST_PCICONF_MOD=.*,MST_PCICONF_MOD="${mft-kernel-module}/lib/modules/${kernel.version}/extras/mft/mst_pciconf.ko,";
              s,PATH=.*,&:/run/current-system/sw/bin,;" $out/usr/bin/mst
      sed -i "s,mft_prefix_location=.*,mft_prefix_location=$out/usr," $out/etc/mft/mft.conf
      mkdir $out/bin
      cp -s $out/usr/bin/* $out/bin
    '';
  };

  oem = stdenv.mkDerivation {
    name = "mft-oem-${ver}";
    inherit src unpackPhase preFixup;

    installPhase = ''
      PATH=/bin:$PATH
      dpkg -x deb/DEBS/mft-oem_${ver}_${arch}.deb $out
    '';
  };

  pcap = stdenv.mkDerivation {
    name = "mft-pcap${ver}";
    inherit src unpackPhase preFixup;

    installPhase = ''
      PATH=/bin:$PATH
      dpkg -x deb/DEBS/mft-pcap_${ver}_${arch}.deb $out
    '';
  };

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

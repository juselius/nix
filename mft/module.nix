{config, lib, pkgs, ...}:
with lib;
let
  kernel = config.boot.kernelPackages.kernel;

  mft = pkgs.callPackage ./mft.nix { inherit kernel; };
in
{
  ###### interface

  options.features.hpc.mft = {
    enable = mkEnableOption "Mellanox MFT";
  };

  ###### implementation

  config = mkIf config.features.hpc.mft.enable {
    environment.etc."mft/mft.conf".source = "${mft.mft}/etc/mft/mft.conf";
    environment.etc."mft/mst.conf".source = "${mft.mft}/etc/mft/mst.conf";
    environment.etc."mft/ca-bundle.crt".source = "${mft.mft}/etc/mft/ca-bundle.crt";

    environment.systemPackages = [ mft.mft kmod ];

    # boot = {
    #   kernelModules = [ "mst_pci" "mst_pciconf" ];
    #   extraModulePackages = [ mft.mft-kernel-module ];
    # };
  };
}

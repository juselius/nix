# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix

let
## TOS Hyper-V
  # dev = "/dev/sda";
  # user = "admin";
  # eth = "eth0";
  # boot = "uefi";
## Dora VMWare
  dev = "/dev/sda";
  user = "admin";
  eth = "ens32";
  boot = "bios";
  initialPassword = "en to tre";
  config = (import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    modules = [
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
      ({ pkgs, lib, ... }:
      let
        nixos-configuration = pkgs.stdenv.mkDerivation {
          name = "nixos-configuration";
          src = ./nixos;
          buildCommand = ''
            mkdir -p $out
            cp -r $src/* $out
            sed -i "s,bootdisk = .*,bootdisk= \"${dev}\";," $out/options.nix
            if [ "${boot}" = "uefi" ]; then
              sed -i "s,uefi = .*,uefi = true;," $out/options.nix
            else
              sed -i "s,uefi = .*,uefi = false;," $out/options.nix
            fi
          '';
        };
        dotfiles = pkgs.stdenv.mkDerivation {
          name = "dotfiles";
          src = ./dotfiles;
          buildCommand = ''
            mkdir -p $out
            cp -r $src/* $out
          '';
        };
      in
      {
        boot.loader.grub.default = "copytomem";
        services.openssh.permitRootLogin = "yes";
        users.extraUsers.root.initialPassword = lib.mkForce "${initialPassword}";
        environment.systemPackages = with pkgs; [
          git wget
        ];
        networking.extraHosts = "10.253.18.100 logger.kube0.local";
        systemd.services.inception = {
        description = "Self-bootstrap a NixOS installation";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "polkit.service" ];
        path = [ "/run/current-system/sw/" ];
        script = with pkgs; ''
          set +e

          if [ ${boot} = "uefi" ]; then
            parted -s ${dev} -- mklabel gpt
            parted -s ${dev} -- mkpart primary 512MiB -4GiB
            parted -s ${dev} -- mkpart primary linux-swap -4GiB 100%
            parted -s ${dev} -- mkpart ESP fat32 1MiB 512MiB
            parted -s ${dev} -- set 3 boot on
            mkfs.ext4 -F -L nixos ${dev}1
            mount ${dev}1 /mnt
            mkswap -L swap ${dev}2
            mkfs.fat -F 32 -n boot ${dev}3
            mkdir -p /mnt/boot
            mount ${dev}3 /mnt/boot
          else
            parted -s ${dev} -- mklabel msdos
            parted -s ${dev} -- mkpart primary 1MiB -4GiB
            parted -s ${dev} -- mkpart primary linux-swap -4GiB 100%
            mkfs.ext4 -F -L nixos ${dev}1
            mount ${dev}1 /mnt
            mkswap -L swap ${dev}2
          fi

          mkdir -p /mnt/etc/nixos/
          cp -r ${nixos-configuration}/* /mnt/etc/nixos
          ${config.system.build.nixos-generate-config}/bin/nixos-generate-config \
            --root /mnt \
            --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix

          sed 's/nixos-enter /&--silent /' \
            ${config.system.build.nixos-install}/bin/nixos-install \
            > /tmp/nixos-install
          chmod 755 /tmp/nixos-install

          sleep 30 # wait for dhcp before install
          /tmp/nixos-install --no-root-passwd -j 1

          cp -r ${dotfiles} /mnt/home/${user}/.dotfiles

          ip=`ip a s dev ${eth} |sed -n 's/ *inet \+\(\([0-9]\+\.\?\)\{4\}\).*/\1/p'`
          wget "http://collector.kube2.local/api/log?entry=$ip" && true

          chroot /mnt echo ${initialPassword} | passwd ${user}
          eject -r -s -F /dev/sr0 && true
          ${systemd}/bin/shutdown -r now
        '';
        environment = config.nix.envVars // {
          inherit (config.environment.sessionVariables) NIX_PATH;
          HOME = "/root";
        };
        serviceConfig = {
          Type = "oneshot";
        };
      };
    })
  ];
}).config;
in
  config.system.build.isoImage


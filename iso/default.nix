# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix
let
  boot = "uefi";
  dev = "/dev/sda";
  eth = "eth0";
  initialPassword = "en to tre fire";
  extraHosts = ''
    10.253.18.114 collector.k2.local
  '';
  configuration = { pkgs, lib, ... }:
    let
      nixos-configuration = pkgs.stdenv.mkDerivation {
        name = "nixos-configuration";
        src = ./nixos;
        buildCommand = ''
          mkdir -p $out
          cp -r $src/* $out
        '';
      };
    in {
      boot.loader.grub.default = "copytomem";
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.initialPassword = lib.mkForce "${initialPassword}";
      networking.extraHosts = extraHosts;
      environment.systemPackages = with pkgs; [
        git wget
      ];
      systemd.services.inception = {
        description = "Self-bootstrap a NixOS installation";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "polkit.service" ];
        path = [ "/run/current-system/sw/" ];
        script = with pkgs; ''
          set +e
          if [ ${boot} = "uefi" ]; then
            parted -s ${dev} -- mklabel gpt; sleep 1
            parted -s ${dev} -- mkpart primary 512MiB -4GiB; sleep 1
            parted -s ${dev} -- mkpart primary linux-swap -4GiB 100%; sleep 1
            parted -s ${dev} -- mkpart ESP fat32 1MiB 512MiB; sleep 1
            parted -s ${dev} -- set 3 boot on; sleep 1
            mkfs.ext4 -F -L nixos ${dev}1; sleep 1
            mount ${dev}1 /mnt
            mkswap -L swap ${dev}2; sleep 1
            mkfs.fat -F 32 -n boot ${dev}3; sleep 1
            mkdir -p /mnt/boot
            mount ${dev}3 /mnt/boot; sleep 1
          else
            parted -s ${dev} -- mklabel msdos; sleep 1
            parted -s ${dev} -- mkpart primary 1MiB -4GiB; sleep 1
            parted -s ${dev} -- mkpart primary linux-swap -4GiB 100%; sleep 1
            mkfs.ext4 -F -L nixos ${dev}1; sleep 1
            mount ${dev}1 /mnt; sleep 1
            mkswap -L swap ${dev}2; sleep 1
          fi
          sleep 2

          mkdir -p /mnt/etc/nixos/
          cp -r ${nixos-configuration}/* /mnt/etc/nixos
          ${config.system.build.nixos-generate-config}/bin/nixos-generate-config \
            --root /mnt \
            --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix

          sed 's/nixos-enter /&--silent /' \
            ${config.system.build.nixos-install}/bin/nixos-install \
            > /tmp/nixos-install
          chmod 755 /tmp/nixos-install

          /tmp/nixos-install --no-root-passwd -j 1

          nixos-enter --root /mnt -c 'echo ${initialPassword} | passwd ${user}'

          ip=`ip a s dev ${eth} | sed -n 's/ *inet \+\(\([0-9]\+\.\?\)\{4\}\).*/\1/p'`
          wget "http://collector.k2.local/api/log?entry=$ip" && true

          # eject -r -s -F /dev/sr0 && true
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
    };
  nixos = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    modules = [
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> configuration
    ];
  };
in
  nixos.config.system.build.isoImage


# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix

let
   dev = "/dev/sda";
   user = "jonas";
   nixos = pkgs.mkDerivation {
     name = "nixos-configuration";
     src = ./nixos;
     buildCommnad = ''
       mkdir -p $out/share/nixos-configuration
       cp -r $src/* $out/share/nixos-configuration
     '';
   };
   dotfiles = pkgs.mkDerivation {
     name = "dotfiles";
     src = ./dotfiles;
     buildCommnad = ''
       mkdir -p $out/share/nixos-configuration
       cp -r $src/* $out/share/nixos-configuration
     '';
   };
   config = (import <nixpkgs/nixos/lib/eval-config.nix> {
     system = "x86_64-linux";
     modules = [
       <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
       ({ pkgs, lib, ... }:
       {
           boot.loader.grub.default = "copytomem";
           services.openssh.permitRootLogin = "yes";
           users.extraUsers.root.initialPassword = lib.mkForce "en to tre";
           environment.systemPackages = with pkgs; [
             git
           ];
           networking.extraHosts = "10.253.18.100 iplogger.k0.local";
           systemd.services.inception = {
             description = "Self-bootstrap a NixOS installation";
             wantedBy = [ "multi-user.target" ];
             after = [ "network.target" "polkit.service" ];
             # TODO: submit a patch for blivet upstream to unhardcode kmod/e2fsprogs/utillinux
             path = [ "/run/current-system/sw/" ];
             script = with pkgs; ''
               sleep 5

               parted -s ${dev} -- mklabel gpt
               parted -s ${dev} -- mkpart primary 512MiB -4GiB
               parted -s ${dev} -- mkpart primary linux-swap -4GiB 100%
               parted -s ${dev} -- mkpart ESP fat32 1MiB 512MiB
               parted -s ${dev} -- set 3 boot on

               mkfs.ext4 -F -L nixos ${dev}
			   mkswap -L swap ${dev}
               mkfs.fat -F 32 -n boot ${dev}

			   mount /dev/disk/by-label/nixos /mnt
               mkdir -p /mnt/boot
               mount /dev/disk/by-label/boot /mnt/boot
               mkdir -p /mnt/etc/nixos/

               cp -r ${nixos-configuration} /mnt/etc/nixos
               ${config.system.build.nixos-generate-config}/bin/nixos-generate-config --root /tmp
               cp /tmp/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/
               sed 's/nixos-enter /&--silent /' ${config.system.build.nixos-install}/bin/nixos-install >/tmp/nixos-install
               chmod 755 /tmp/nixos-install
               /tmp/nixos-install --no-root-passwd -j 1
               passwd jonas "jonas"
               cp -r ${dotfiles} /home/${user}/.dotfiles
			   # eject -r -s -F /dev/sr0 && true
               # ip=`ip a s dev eno2 |sed -n 's/ *inet \+\(\([0-9]\+\.\?\)\{4\}\).*/\1/p'`
               # wget "http://iplogger.k0.local/api/log?entry=$ip" && true
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


# build an ISO image that will auto install NixOS and reboot
# $ nix-build make-iso.nix

let
   config = (import <nixpkgs/nixos/lib/eval-config.nix> {
     system = "x86_64-linux";
     modules = [
       <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
       ({ pkgs, lib, ... }:
         let
           cfg = pkgs.writeText "configuration.nix" ''
            # Edit this configuration file to define what should be installed on
            # your system.  Help is available in the configuration.nix(5) man page
            # and in the NixOS manual (accessible by running ‘nixos-help’).

            { config, pkgs, lib, ... }:
            {
              imports = [ ./hardware-configuration.nix ];

              # Use UEFI
              boot.loader.systemd-boot.enable = true;
              # Use the GRUB 2 boot loader.
              # boot.loader.grub.enable = true;
              # boot.loader.grub.version = 2;
              # boot.loader.grub.device = "/dev/sda";
              boot.cleanTmpDir = true;

              # Select internationalisation properties.
              i18n = {
                 consoleFont = "Lat2-Terminus16";
                 consoleKeyMap = "us";
                 defaultLocale = "en_US.UTF-8";
              };

              # Set your time zone.
              time.timeZone = "Europe/Oslo";

              networking.search = [ "itpartner.no" "itpartner.intern" ];
              networking.extraHosts = '''
                10.253.18.100 k0-0 etcd0
                10.253.18.101 k0-1 etcd1 gitlab.cluster.local
                10.253.18.102 k0-2 etcd2
                10.253.18.103 k0-3
                10.253.18.107 k0-4
                10.253.18.108 k0-5
                10.253.18.109 k1-0
                10.253.18.110 k1-1
                10.253.18.106 fs0-0
                10.1.2.164    fs0-1
              ''';

              nixpkgs.config.allowUnfree = true;
              # List packages installed in system profile. To search by name, run:
              # $ nix-env -qaP | grep wget
              environment.systemPackages = with pkgs; [
                stdenv
                findutils
                coreutils
                psmisc
                iputils
                nettools
                netcat
                rsync
                htop
                iotop
                wget
                neovim
                python
                file
                bc
                sshuttle
                termite
                home-manager
                nix-prefetch-git
              ];

              programs.fish.enable = true;
              programs.tmux.enable = true;

              # Enable the OpenSSH daemon.
              services.openssh.enable = true;
              services.dnsmasq.enable = true;

              # this is set for install not to ask for password
              users.extraUsers.root = {
                  initialPassword = lib.mkForce "en to tre";
                  openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKiAS30ZO+wgfAqDE9Y7VhRunn2QszPHA5voUwo+fGOf jonas"
                  ];
              };

              security.sudo.wheelNeedsPassword = false;
              security.sudo.extraConfig = '''
                  Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
                  Defaults:root,%wheel env_keep+=NIX_PATH
                  Defaults:root,%wheel env_keep+=TERMINFO_DIRS
                  Defaults env_keep+=SSH_AUTH_SOCK
                  Defaults lecture=never
                  Defaults shell_noargs
                  root   ALL=(ALL) SETENV: ALL
              ''';

              security.rtkit.enable = true;

              # The NixOS release to be compatible with for stateful data such as databases.
              system.stateVersion = "19.03";
              system.autoUpgrade.enable = false;
            }
           '';
         in {
           boot.loader.grub.default = "copytomem";
           services.openssh.permitRootLogin = "yes";
           users.extraUsers.root.initialPassword = lib.mkForce "en to tre";
           environment.systemPackages = with pkgs; [
             mailutils
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

               parted -s /dev/sda -- mklabel gpt
               parted -s /dev/sda -- mkpart primary 512MiB -4GiB
               parted -s /dev/sda -- mkpart primary linux-swap -4GiB 100%
               parted -s /dev/sda -- mkpart ESP fat32 1MiB 512MiB
               parted -s /dev/sda -- set 3 boot on

               mkfs.ext4 -F -L nixos /dev/sda1
			   mkswap -L swap /dev/sda2
               mkfs.fat -F 32 -n boot /dev/sda3

			   mount /dev/disk/by-label/nixos /mnt
               mkdir -p /mnt/boot
               mount /dev/disk/by-label/boot /mnt/boot
               mkdir -p /mnt/etc/nixos/

               ${config.system.build.nixos-generate-config}/bin/nixos-generate-config --root /mnt
               cp ${cfg} /mnt/etc/nixos/configuration.nix
               sed 's/nixos-enter /&--silent /' ${config.system.build.nixos-install}/bin/nixos-install >/tmp/nixos-install
               chmod 755 /tmp/nixos-install
               /tmp/nixos-install --no-root-passwd -j 1
			   eject -r -s -F /dev/sr0 && true
               ip=`ip a s dev eno2 |sed -n 's/ *inet \+\(\([0-9]\+\.\?\)\{4\}\).*/\1/p'`
               wget "http://iplogger.k0.local/api/log?entry=$ip" && true
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


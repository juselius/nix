{ config, lib, pkgs, ... }:

with lib;

{ boot.isContainer = true;
  networking.hostName = mkDefault "foo";
  networking.useDHCP = false;

  environment.systemPackages = with pkgs; [
     wget
     stdenv
     findutils
     coreutils
     psmisc
     iputils
     nettools
     netcat
     vim
     file
     git
     ((pkgs.callPackage ./nix-home.nix) { })
  ];

  programs.zsh.enable = true;
  programs.tmux.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraGroups = [
      { name = "jonas"; gid = 1000; }
  ];

  users.extraUsers.jonas = {
     description = "Jonas Juselius";
     home = "/home/jonas";
     group = "jonas";
     extraGroups = ["users" "wheel" "root" "adm" "cdrom"];
     uid = 1000;
     isNormalUser = true;
     createHome = true;
     useDefaultShell = false;
     shell = pkgs.zsh;
  };

  security.sudo.configFile =
    ''
      Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
      Defaults:root,%wheel env_keep+=NIX_PATH
      Defaults:root,%wheel env_keep+=TERMINFO_DIRS
      Defaults env_keep+=SSH_AUTH_SOCK
      Defaults lecture=never
      Defaults shell_noargs
      root   ALL=(ALL) SETENV: ALL
      %wheel ALL=(ALL) NOPASSWD: ALL, SETENV: ALL
     '';
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";

}


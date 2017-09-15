{ config, lib, pkgs, ... }:

with lib;

{ boot.isContainer = true;
  networking.hostName = mkDefault "nixos";
  networking.useDHCP = false;

  environment.systemPackages = with pkgs; [
     wget
     stdenv
     coreutils
     psmisc
     iputils
     nettools
     netcat
     vim
     file
  ];

  programs.fish.enable = true;
  programs.tmux.enable = true;

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";

}


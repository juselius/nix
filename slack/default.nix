with import <nixpkgs> {};
let
  version = "2.7.1";
in
  pkgs.slack.overrideAttrs (oldAttrs: rec {
    name = "slack-${version}";
    src = fetchurl {
      url = "https://downloads.slack-edge.com/linux_releases/slack-desktop-${version}-amd64.deb";
      sha256 = "1na163lr0lfii9z1v4q9a3scqlaxg0s561a9nhadbqj03k74dw6s";
    };
  })

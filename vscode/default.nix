with (import <nixpkgs> {});
let
  version = "1.18.1";
  channel = "stable";
  plat = "linux-x64";
  archive_fmt = "tar.gz";
  url = "https://vscode-update.azurewebsites.net/${version}/${plat}/${channel}";
in
pkgs.vscode.overrideAttrs (attrs: rec {
  name = "vscode-${version}";
  src = fetchurl {
    name = "VSCode_${version}_${plat}.${archive_fmt}";
    url = "https://vscode-update.azurewebsites.net/${version}/${plat}/${channel}";
    sha256 = "0h7nfyrn4ybm9p1czjb48p3cd3970hpyn6pj8l4ir1hqygcq6dwi";
  };
})

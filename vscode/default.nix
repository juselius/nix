with (import <nixpkgs> {});
let
  version = "1.13.1";
  channel = "stable";
  plat = "linux-x64";
in
pkgs.vscode.overrideAttrs (attrs: rec {
  name = "vscode-${version}";
  src = fetchurl {
    name = "VSCode_${version}_${plat}.${archive_fmt}";
    url = "https://vscode-update.azurewebsites.net/${version}/${plat}/${channel}";
    sha256 = "";
  };
})

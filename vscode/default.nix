with import <nixpkgs> {};
# pkgs.callPackage ./vscode.nix {}
# with import /home/jonas/src/nixpkgs/pkgs/applications/editors/vscode {};
# with import /home/jonas/src/nixpkgs {};
let
  plat = "linux-x64";
  archive_fmt = "tar.gz";
  # all-hies = import (fetchTarball "https://github.com/infinisil/all-hies/tarball/master") {};
  # hie = all-hies.selection { selector = p: { inherit (p) ghc864; }; };
in
pkgs.vscode.overrideAttrs (attrs: rec {
    version = "1.38.1";
    name = "vscode-${version}";

    src = fetchurl {
      name = "VSCode_${version}_${plat}.${archive_fmt}";
      url = "https://vscode-update.azurewebsites.net/${version}/${plat}/stable";
      sha256 = "1wxaxz2q4qizh6f23ipz8ihay6bpjdq0545vijqd84fqazcji6sq";
    };
    # postFixup = ''
    #     wrapProgram $out/bin/code --prefix PATH : ${lib.makeBinPath [hie]}
    # '';
})

{pkgs, ...}:
with import ./version.nix ;
#pkgs.vscode-with-extensions.overrideAttrs (attrs: rec {
pkgs.vscode.overrideAttrs (attrs: rec {
  name = "vscode-${version}";
  src = pkgs.fetchurl {
    name = archive;
    url = url;
    sha256 = sha256;
  };
  buildInputs = with pkgs; [
    wrapGAppsHook
    xorg.libXScrnSaver
    xorg.libxkbfile
    libsecret
    at_spi2_atk
  ];

  # vscodeExtensions =
  #   pkgs.vscode-utils.extensionsFromVscodeMarketplace [
  #     {
  #       name = "csharp";
  #       publisher = "ms-vscode";
  #       version = "1.17.1";
  #       sha256 = "0bpf2vf4r7q42sc7vpx9qb8dyzffg5ihykvshnkj4ll8xwhxarhg";
  #     }
  #   ];
})

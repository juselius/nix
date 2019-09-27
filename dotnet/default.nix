with (import <nixpkgs> {});
let
  version = "3.0.100";
in
pkgs.dotnet-sdk.overrideAttrs (attrs: rec {
  name = "dotnet-sdk-${version}";
  src = pkgs.fetchurl {
    url = "https://dotnetcli.azureedge.net/dotnet/Sdk/${version}/dotnet-sdk-${version}-linux-x64.tar.gz";
    sha256 = "1hh1mkqjf1qfvk78yx73k0kvk4czv8zdc7rv17b7z1awkpi8y28j";
  };
})


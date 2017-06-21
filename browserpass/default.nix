let pkgs = import <nixpkgs> {};
    stdenv = pkgs.stdenv;
in rec {
  browserpass = stdenv.mkDerivation {
    version = "1.0.6";
    name = "browserpass-${browserpass.version}";
    builder = pkgs.writeScript "builder.sh" ''
      #!/usr/bin/env bash
      source $stdenv/setup
      ${pkgs.unzip}/bin/unzip $src
      cd ${browserpass.name}
      export GOPATH=`pwd`
      export GIT_SSL_NO_VERIFY=1
      go get -d
      make static-files browserpass-linux64
      mkdir -p $out/libexec/browserpass
      cp browserpass-linux64 chrome-host.json chrome-policy.json firefox-host.json install.sh $out/libexec/browserpass
    '';
    src = pkgs.fetchurl {
      url = "https://github.com/dannyvankooten/browserpass/archive/1.0.6.zip";
      sha256 = "0zsh3hdjyq8d1v3d7gh5cpds2pfy106l0bz124nggg1mvankj9rj";
    };
    buildInputs = with pkgs; [
      zip
      go
      git
    ];
  };
}

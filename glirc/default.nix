with import <nixpkgs> {};

pkgs.haskellPackages.glirc.overrideDerivation (oldAttrs: rec {
    version = "2.22";
    sha256 = "1ivqv0iiz38anmn247j4mkvjcbvckw0qq92305gk4s3db9x069zg";
    src = fetchgit {
      name = "glirc-${version}-src";
      url = "https://github.com/glguy/irc-core.git";
      rev = "cde4fa30c94dac0d973ba82c5d9a50c001a82ef3";
      sha256 = "1ivqv0iiz38anmn247j4mkvjcbvckw0qq92305gk4s3db9x069zg";
    };
  })

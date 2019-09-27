with (import <nixpkgs> {});
callPackage ./5.14.nix {
    inherit (darwin) libobjc;
    inherit (darwin.apple_sdk.frameworks) Foundation;
}

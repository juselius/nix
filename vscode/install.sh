#!/usr/bin/env bash

if [ $# != 1 ]; then
    echo "install.sh <version>"
    exit 1
fi

url=$(nix-instantiate --eval -E 'let x = import ./version.nix; in x.url' | sed 's/"//g')
sha=$(nix-prefetch-url $url)

sed  -i "s/version = .*/version = \"$1\";/; s/sha256 = .*;/sha256 = \"$sha\";/" version.nix

nix-env -i -f .

#!/bin/sh

version=$1
tarball=Wavebox_${version//\./_}_linux_x86_64.tar.gz

nix-prefetch-url "https://github.com/wavebox/waveboxapp/releases/download/v${version}/${tarball}";

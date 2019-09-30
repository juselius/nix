#!/usr/bin/env bash

[ ! -d FAKE ] && git clone https://github.com/fsharp/FAKE.git

cd FAKE
git pull
rm -f global.json
dotnet restore build.proj
cd src/app/fake-cli
dotnet publish -c Release -o ../../../../deploy
cd ../../../..
nix-env -i -f .


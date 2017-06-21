#!/usr/bin/env bash

[ ! -e ~/.dotfiles ] && git clone https://github.com/juselius/dotfiles.git ~/.dotfiles

cd ~/.dotfiles
git checkout nixos
git pull
./install-dotfiles.sh

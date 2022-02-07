#! /bin/bash
# Fix me!

var=~/repos/dotfiles

mkdir -p ~/.config/nvim/general
mkdir -p ~/.config/nvim/keys
mkdir -p ~/.config/nvim/vim-plug
mkdir -p ~/.config/nvim/plug-conf
mkdir -p ~/.config/bspwm
mkdir -p ~/.config/sxhkd
mkdir -p ~/.config/polybar
mkdir -p ~/.config/i3
mkdir -p ~/.config/rofi

# f flag to override/update in case it already exists
# s for the soft link
# v for the verbose, to print the link name
ln -snfv $var/.zshrc ~/
ln -snfv $var/.vimrc ~/
ln -snfv $var/i3/config ~/.config/i3/
ln -snfv $var/rofi/config.rasi ~/.config/rofi/
ln -snfv $var/bspwm/bspwmrc ~/.config/bspwm
ln -snfv $var/sxhkd/sxhkdrc ~/.config/sxhkd
ln -snfv $var/polybar/config ~/.config/polybar
ln -snfv $var/alacritty ~/.config/
ln -snfv $var/.doom.d ~/
ln -snfv $var/picom.conf ~/.config/
ln -snfv $var/.xinitrc ~/
ln -snfv $var/nvim/init.vim ~/.config/nvim/
ln -sfnv $var/nvim/coc-setting.json ~/.config/nvim/
ln -snfv $var/nvim/general/* ~/.config/nvim/general/
ln -snfv $var/nvim/keys/* ~/.config/nvim/keys/
ln -snfv $var/nvim/vim-plug/* ~/.config/nvim/vim-plug/
ln -sfnv $var/nvim/plug-conf/* ~/.config/nvim/plug-conf/

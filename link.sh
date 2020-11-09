#! /bin/bash
# Fix me!

var=~/repos/dotfiles
echo "Success for the string concatenation $var"

# f flag to override/update in case it already exists
# s for the soft link
# v for the verbose, to print the link name
ln -sfv $var/.zshrc ~/
ln -sfv $var/.vimrc ~/
ln -sfv $var/alacritty ~/.config/
ln -sfv $var/.doom.d ~/
ln -sfv $var/picom.conf ~/.config/
ln -sfv $var/.xinitrc ~/
ln -sfv $var/nvim/* ~/.config/nvim/
ln -sfv $var/nvim/general/* ~/.config/nvim/general/
ln -sfv $var/nvim/vim-plug/* ~/.config/nvim/vim-plug/
ln -sfv $var/nvim/plug-conf/* ~/.config/nvim/plug-conf/

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

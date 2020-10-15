#! /bin/bash
# Fix me!

var=~/repos/dotfiles
echo "Success for the string concatenation $var"

# f flag to override/update in case it already exists
# s for the soft link
# v for the verbose, to print the link name
ln -sfv $var/.zshrc ~/.zshrc
ln -sfv $var/.vimrc ~/.vimrc
# if alacritty directory doesn't exist then create one and proceed to the linking
ln -sfv $var/alacritty.yml ~/.config/alacritty/alacritty.yml

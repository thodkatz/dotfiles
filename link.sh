#! /bin/bash
# Fix me!

var=~/repos/dotfiles
echo "Success for the string concatenation $var"

# f flag to override/update in case it already exists
ln -sf $var/.zshrc ~/.zshrc
ln -sf $var/.vimrc ~/.vimrc

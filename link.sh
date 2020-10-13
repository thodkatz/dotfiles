#! /bin/bash
# Fix me!

var=~/repos/dotfiles

# f flag to override/update in case it already exists
ln -sf $var/.zshrc ~/.zshrc
echo "Success for the string concatenation $var"

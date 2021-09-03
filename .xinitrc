#! /bin/bash
# This is a script executed by startx
# Notes: Iinstead of comment uncomment the kde and the dwm, you can use a login manager like lightDM

# kde-plasma
#export DESKTOP_SESSION=plasma
#exec startplasma-x11

# dwm
# feh --bg-fill ~/MEGA/media/pictures/space_lost.jpg
# # picom is a wrapper of compton for Arch Linux
# picom --config ~/.config/picom.conf & 
# while true; do
# 		xsetroot -name "$(date)"
# 		sleep 5s
# done &

# if dunst systemctl failes. Then it is probably due to the lack of a display manager
# confirmed!
systemctl --user import-environment DISPLAY
exec dbus-launch dwm

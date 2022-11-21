#!/bin/sh
nitrogen --restore &
picom --config ~/.config/picom/picom.conf &
dunst -conf /home/dk/.config/dunst/qtilerc &
nm-applet &
cbatticon -i standard BAT1 &
volumeicon &
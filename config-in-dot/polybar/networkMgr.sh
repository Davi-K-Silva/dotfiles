#!/bin/bash
#bspc rule -a 'Alacritty' -o state=floating
bspc rule -a '*' -o state=floating
alacritty -e nmtui
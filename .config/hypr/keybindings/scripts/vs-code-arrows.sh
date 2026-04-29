#!/usr/bin/env bash

# Get the focused window class
#
#
class=$(hyprctl activewindow -j | jq -r ".class")

if [ $class == "code" ]; then
  
  case "$1" in 
  "right")
    wtype -M alt -P right -p right -m alt
  ;;

  "down")
    wtype -M alt -P down -p down -m alt
  ;;

  "left")
    wtype -M alt -P left -p left -m alt
  ;;

  "up")
    wtype -M alt -P up -p up -m alt
  ;;
  esac
else
  hyprctl dispatch movefocus $1
fi

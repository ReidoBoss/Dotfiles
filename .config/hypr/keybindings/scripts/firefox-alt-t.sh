#!/usr/bin/env bash
class=$(hyprctl activewindow -j | jq -r ".class")
if [ $class == "firefox" ]; then  
  wtype -M alt t -m alt
else
  kitty
fi


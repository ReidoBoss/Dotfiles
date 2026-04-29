#!/usr/bin/env bash

# Get the active window class raw (no quotes)
class=$(hyprctl activewindow -j | jq -r ".class")
allowed_classes=("firefox" "firefox-developer-edition")
is_class_found=false
key=$1

# Check if current class is in our allowed list
for item in "${allowed_classes[@]}"; do
    if [[ "$class" == "$item" ]]; then
        is_class_found=true
        break
    fi
done

if [ "$is_class_found" = true ]; then
    case $key in 
        "c")
            hyprctl dispatch sendshortcut "CTRL, C, class:^($class)$"
            ;;        
        "v")
            hyprctl dispatch sendshortcut "CTRL, V, class:^($class)$"
            ;;        
        "s")
            hyprctl dispatch sendshortcut "CTRL, S, class:^($class)$"
            ;;
        "a")
            hyprctl dispatch sendshortcut "CTRL, A, class:^($class)$"
            ;;
            
        "shift_left")
            hyprctl dispatch sendshortcut "SHIFT, home, class:^($class)$"
            ;;
        "shift_right")
            hyprctl dispatch sendshortcut "SHIFT, end, class:^($class)$"
            ;;
       
        "super_left")
            hyprctl dispatch sendshortcut "CTRL_SHIFT, left, class:^($class)$"
            ;;
        "super_right")
            hyprctl dispatch sendshortcut "CTRL_SHIFT, right, class:^($class)$"
            ;;
        "super_up")
            hyprctl dispatch sendshortcut "CTRL_SHIFT, up, class:^($class)$"
            ;;
        "super_down")
            hyprctl dispatch sendshortcut "CTRL_SHIFT, down, class:^($class)$"
            ;;
    esac 
else
    # This block handles all other apps
    case $key in
        "c") hyprctl dispatch sendshortcut "CTRL, C, activewindow" ;;
        "v") hyprctl dispatch sendshortcut "CTRL, V, activewindow" ;;
        "s") hyprctl dispatch sendshortcut "CTRL, S, activewindow" ;;
        "a") hyprctl dispatch sendshortcut "CTRL, A, activewindow" ;;
        
        "super_left")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "SUPER SHIFT, left, activewindow"
            else
                hyprctl dispatch sendshortcut "CTRL_SHIFT, left, activewindow"
            fi
            ;;
        "super_right")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "SUPER SHIFT, right, activewindow"
            else
                hyprctl dispatch sendshortcut "CTRL_SHIFT, right, activewindow"
            fi
            ;;
        "super_up")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "SUPER SHIFT, up, activewindow"
            else
                hyprctl dispatch sendshortcut "CTRL_SHIFT, up, activewindow"
            fi
            ;;
        "super_down")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "SUPER SHIFT, down, activewindow"
            else
                hyprctl dispatch sendshortcut "CTRL_SHIFT, down, activewindow"
            fi
            ;;

        "shift_left")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "ALT SHIFT, left, activewindow"
            else
                hyprctl dispatch sendshortcut "SHIFT HOME, left, activewindow"
            fi
            ;;
        "shift_right")
            if [ "$class" == "code" ]; then
                hyprctl dispatch sendshortcut "ALT SHIFT, right, activewindow"
            else
                hyprctl dispatch sendshortcut "SHIFT END, right, activewindow"
            fi
            ;;

          esac
fi

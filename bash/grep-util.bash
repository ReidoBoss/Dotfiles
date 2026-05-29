gpick() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
gpick - live grep picker with preview using pure old Bash

Usage:
  gpick [initial search] [extensions] [directory]

Examples:
  gpick
  gpick defineProps vue,ts src
  gpick "case class" scala app
  gpick "TODO" "" .

Controls:
  Type text      Grep files live
  Backspace      Delete character
  Ctrl+u         Clear search
  Down / Ctrl+n  Move down
  Up / Ctrl+p    Move up
  Enter          Open selected file at first match
  Esc            Quit

Notes:
  Pure Bash version. No fzf, no plugins, no mapfile.
  Ignores .git, node_modules, dist, build, and target.
EOF
    return
  fi

  local query="$1"
  local exts="$2"
  local dir="${3:-.}"

  local all="/tmp/gpick-all-$$"
  local filtered="/tmp/gpick-filtered-$$"

  > "$all"
  > "$filtered"

  if [ -z "$exts" ]; then
    find "$dir" \
      -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name target \) -prune -o \
      -type f -print 2>/dev/null \
      > "$all"
  else
    local old_ifs ext
    old_ifs="$IFS"
    IFS=","

    for ext in $exts; do
      ext="${ext// /}"
      ext="${ext#.}"

      find "$dir" \
        -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name target \) -prune -o \
        -type f -name "*.$ext" -print 2>/dev/null \
        >> "$all"
    done

    IFS="$old_ifs"
    sort -u "$all" -o "$all"
  fi

  if [ ! -s "$all" ]; then
    echo "No files found."
    rm -f "$all" "$filtered"
    return
  fi

  local selected_num=1
  local offset=1
  local total=0

  update_filter() {
    > "$filtered"

    if [ -z "$query" ]; then
      total=0
      selected_num=1
      offset=1
      return
    fi

    while IFS= read -r file; do
      grep -Il -- "$query" "$file" 2>/dev/null
    done < "$all" > "$filtered"

    total=$(wc -l < "$filtered" | tr -d ' ')

    if [ "$total" -eq 0 ]; then
      selected_num=1
      offset=1
      return
    fi

    if [ "$selected_num" -gt "$total" ]; then
      selected_num="$total"
    fi

    if [ "$selected_num" -lt 1 ]; then
      selected_num=1
    fi
  }

  draw_gpick() {
    local rows list_height preview_height end i current_file preview_file

    rows=$(tput lines 2>/dev/null || echo 24)

    list_height=$((rows / 2 - 4))
    [ "$list_height" -lt 5 ] && list_height=5

    preview_height=$((rows - list_height - 8))
    [ "$preview_height" -lt 5 ] && preview_height=5

    if [ "$selected_num" -lt "$offset" ]; then
      offset="$selected_num"
    fi

    if [ "$selected_num" -ge $((offset + list_height)) ]; then
      offset=$((selected_num - list_height + 1))
    fi

    end=$((offset + list_height - 1))
    [ "$end" -gt "$total" ] && end="$total"

    clear

    printf "\033[1;36mgpick live\033[0m  grep: \033[1;33m%s\033[0m  matches: %s\n" "$query" "$total"
    printf "\033[90mtype = grep | arrows/Ctrl+n/Ctrl+p = move | Ctrl+u = clear | Enter = open | Esc = quit\033[0m\n\n"

    if [ -z "$query" ]; then
      echo "Start typing to grep files..."
      return
    fi

    if [ "$total" -eq 0 ]; then
      echo "No matching files."
      return
    fi

    i="$offset"

    while [ "$i" -le "$end" ]; do
      current_file=$(sed -n "${i}p" "$filtered")

      if [ "$i" -eq "$selected_num" ]; then
        printf "\033[7m%3s) %s\033[0m\n" "$i" "$current_file"
      else
        printf "\033[1;32m%3s)\033[0m %s\n" "$i" "$current_file"
      fi

      i=$((i + 1))
    done

    preview_file=$(sed -n "${selected_num}p" "$filtered")

    printf "\n\033[1;36mPreview:\033[0m \033[1;32m%s\033[0m\n" "$preview_file"
    printf "\033[90m────────────────────────────────────────\033[0m\n"

    grep -n -C 3 --color=always -- "$query" "$preview_file" 2>/dev/null |
      head -n "$preview_height"
  }

  update_filter

  while true; do
    draw_gpick

    local key rest file editor line

    IFS= read -rsn1 key

    case "$key" in
      "")
        if [ "$total" -eq 0 ]; then
          continue
        fi

        file=$(sed -n "${selected_num}p" "$filtered")
        line=$(grep -n -m 1 -- "$query" "$file" 2>/dev/null | cut -d: -f1)

        rm -f "$all" "$filtered"

        editor="${EDITOR:-vim}"
        clear

        if echo "$editor" | grep -q "vim" && [ -n "$line" ]; then
          "$editor" "+$line" "$file"
        else
          "$editor" "$file"
        fi

        return
        ;;

      $'\177'|$'\b')
        query="${query%?}"
        selected_num=1
        offset=1
        update_filter
        ;;

      $'\025')
        query=""
        selected_num=1
        offset=1
        update_filter
        ;;

      $'\016')
        [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
        ;;

      $'\020')
        [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
        ;;

      $'\033')
        IFS= read -rsn2 -t 0.05 rest

        case "$rest" in
          "[A")
            [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
            ;;
          "[B")
            [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
            ;;
          *)
            rm -f "$all" "$filtered"
            clear
            return
            ;;
        esac
        ;;

      *)
        query="${query}${key}"
        selected_num=1
        offset=1
        update_filter
        ;;
    esac
  done
}

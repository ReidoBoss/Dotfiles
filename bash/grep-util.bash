gpick() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
gpick - grep files and choose one with a small Bash TUI preview

Usage:
  gpick "search text" "extensions" "directory"

Examples:
  gpick "defineProps" "vue,ts" .
  gpick "case class" "scala" app
  gpick "useState" "tsx,ts" src
  gpick "TODO"

Arguments:
  search text   Text you want to grep
  extensions    Comma-separated file extensions, example: vue,ts,scala
  directory     Directory to search in. Defaults to current directory

Controls:
  j / Down Arrow   Move down
  k / Up Arrow     Move up
  Enter            Open selected file
  q                Quit

Notes:
  If extensions is empty, gpick searches all files.
  It ignores .git, node_modules, dist, build, and target.
EOF
    return
  fi

  local search="$1"
  local exts="$2"
  local dir="${3:-.}"
  local tmp file total line editor

  [ -z "$search" ] && read -p "Search text: " search
  [ -z "$exts" ] && read -p "Extensions ex: ts,vue,scala. Empty = all: " exts

  tmp="/tmp/gpick-files-$$"
  > "$tmp"

  if [ -z "$exts" ]; then
    find "$dir" \
      -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name target \) -prune -o \
      -type f -exec grep -Il -- "$search" {} \; \
      > "$tmp" 2>/dev/null
  else
    local old_ifs ext
    old_ifs="$IFS"
    IFS=","

    for ext in $exts; do
      ext="${ext// /}"
      ext="${ext#.}"

      find "$dir" \
        -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name target \) -prune -o \
        -type f -name "*.$ext" -exec grep -Il -- "$search" {} \; \
        >> "$tmp" 2>/dev/null
    done

    IFS="$old_ifs"
    sort -u "$tmp" -o "$tmp"
  fi

  if [ ! -s "$tmp" ]; then
    echo "No matching files found."
    rm -f "$tmp"
    return
  fi

  total=$(wc -l < "$tmp" | tr -d ' ')

  local selected_num=1
  local offset=1

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

    printf "\033[1;36mgpick TUI\033[0m  search: \033[1;33m%s\033[0m  files: %s\n" "$search" "$total"
    printf "\033[90mj/k or arrows = move | Enter = open | q = quit | gpick -h = help\033[0m\n\n"

    i="$offset"

    while [ "$i" -le "$end" ]; do
      current_file=$(sed -n "${i}p" "$tmp")

      if [ "$i" -eq "$selected_num" ]; then
        printf "\033[7m%3s) %s\033[0m\n" "$i" "$current_file"
      else
        printf "\033[1;32m%3s)\033[0m %s\n" "$i" "$current_file"
      fi

      i=$((i + 1))
    done

    preview_file=$(sed -n "${selected_num}p" "$tmp")

    printf "\n\033[1;36mPreview:\033[0m \033[1;32m%s\033[0m\n" "$preview_file"
    printf "\033[90m────────────────────────────────────────\033[0m\n"

    grep -n -C 3 -- "$search" "$preview_file" 2>/dev/null | head -n "$preview_height"
  }

  while true; do
    draw_gpick

    local key rest
    IFS= read -rsn1 key

    case "$key" in
      q|Q)
        rm -f "$tmp"
        return
        ;;

      j)
        [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
        ;;

      k)
        [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
        ;;

      "")
        file=$(sed -n "${selected_num}p" "$tmp")
        rm -f "$tmp"

        line=$(grep -n -m 1 -- "$search" "$file" 2>/dev/null | cut -d: -f1)
        editor="${EDITOR:-vim}"

        if echo "$editor" | grep -q "vim" && [ -n "$line" ]; then
          "$editor" "+$line" "$file"
        else
          "$editor" "$file"
        fi

        return
        ;;

      $'\033')
        IFS= read -rsn2 rest

        case "$rest" in
          "[A")
            [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
            ;;
          "[B")
            [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
            ;;
        esac
        ;;
    esac
  done
}

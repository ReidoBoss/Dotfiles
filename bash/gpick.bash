gpick() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
gpick - lazy grep picker with preview using pure old Bash

Usage:
  gpick [initial search] [extensions] [directory]

Examples:
  gpick
  gpick defineProps vue,ts src
  gpick "case class" scala app

Controls:
  Type text      Edit grep query only
  Tab            Run grep
  Enter          Grep if changed, otherwise open selected file at first match
  Backspace      Delete character
  Ctrl+u         Clear query
  Ctrl+r         Rescan files
  Down / Ctrl+n  Move down
  Up / Ctrl+p    Move up
  Esc            Quit
EOF
    return
  fi

  local query="$1"
  local exts="$2"
  local dir="${3:-.}"

  local all="/tmp/gpick-all-$$"
  local filtered="/tmp/gpick-filtered-$$"

  local scanned=0
  local dirty=1
  local selected_num=1
  local offset=1
  local total=0

  > "$all"
  > "$filtered"

  scan_files() {
    > "$all"

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

    scanned=1
  }

  update_filter() {
    [ "$scanned" -eq 0 ] && scan_files

    > "$filtered"

    if [ -z "$query" ]; then
      total=0
      selected_num=1
      offset=1
      dirty=0
      return
    fi

    while IFS= read -r file; do
      grep -IlF -- "$query" "$file" 2>/dev/null
    done < "$all" > "$filtered"

    total=$(wc -l < "$filtered" | tr -d ' ')

    selected_num=1
    offset=1
    dirty=0
  }

  draw_gpick() {
    local rows list_height preview_height end i current_file preview_file status

    rows=$(tput lines 2>/dev/null || echo 24)

    list_height=$((rows / 2 - 4))
    [ "$list_height" -lt 5 ] && list_height=5

    preview_height=$((rows - list_height - 8))
    [ "$preview_height" -lt 5 ] && preview_height=5

    [ "$selected_num" -lt "$offset" ] && offset="$selected_num"
    [ "$selected_num" -ge $((offset + list_height)) ] && offset=$((selected_num - list_height + 1))

    end=$((offset + list_height - 1))
    [ "$end" -gt "$total" ] && end="$total"

    if [ "$dirty" -eq 1 ]; then
      status="not grepped yet"
    else
      status="grepped"
    fi

    clear
    printf "\033[1;36mgpick lazy\033[0m  grep: \033[1;33m%s\033[0m  matches: %s  \033[90m%s\033[0m\n" "$query" "$total" "$status"
    printf "\033[90mtype = edit | Tab = grep | Enter = grep/open | Ctrl+r = rescan | Esc = quit\033[0m\n\n"

    if [ "$dirty" -eq 1 ]; then
      echo "Press Tab or Enter to grep."
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

    grep -n -C 3 --color=always -F -- "$query" "$preview_file" 2>/dev/null |
      head -n "$preview_height"
  }

  while true; do
    draw_gpick

    local key rest file editor line
    IFS= read -rsn1 key

    case "$key" in
      "")
        if [ "$dirty" -eq 1 ] || [ "$total" -eq 0 ]; then
          update_filter
          continue
        fi

        file=$(sed -n "${selected_num}p" "$filtered")
        line=$(grep -n -m 1 -F -- "$query" "$file" 2>/dev/null | cut -d: -f1)

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

      $'\t')
        update_filter
        ;;

      $'\177'|$'\b')
        query="${query%?}"
        dirty=1
        ;;

      $'\025')
        query=""
        total=0
        selected_num=1
        offset=1
        > "$filtered"
        dirty=0
        ;;

      $'\022')
        scanned=0
        dirty=1
        ;;

      $'\016'|j)
        [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
        ;;

      $'\020'|k)
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
        dirty=1
        ;;
    esac
  done
}

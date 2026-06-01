vfind() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
vfind - lazy file finder with preview using pure old Bash

Usage:
  vfind [initial query] [extensions] [directory]

Examples:
  vfind
  vfind UserService
  vfind Button vue,ts src

Controls:
  Type text      Edit query only
  Tab            Search
  Enter          Search if changed, otherwise open selected file
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

  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/vfind.XXXXXX") || return

  local all="$tmpdir/all"
  local filtered="$tmpdir/filtered"

  local scanned=0
  local dirty=1
  local selected_num=1
  local offset=1
  local total=0

  > "$all"
  > "$filtered"

  cleanup_vfind() {
    tput cnorm 2>/dev/null
    rm -rf "$tmpdir"
  }

  vfind_editor() {
    if [ -n "$VISUAL" ]; then
      printf "%s\n" "$VISUAL"
    elif [ -n "$EDITOR" ]; then
      printf "%s\n" "$EDITOR"
    elif command -v nvim >/dev/null 2>&1; then
      printf "%s\n" "nvim"
    else
      printf "%s\n" "vim"
    fi
  }

  read_vfind_key() {
    if [ -n "$ZSH_VERSION" ]; then
      IFS= read -rs -k 1 "$1"
    else
      IFS= read -rsn1 "$1"
    fi
  }

  read_vfind_keys_timeout() {
    if [ -n "$ZSH_VERSION" ]; then
      IFS= read -rs -t "$3" -k "$2" "$1"
    else
      IFS= read -rsn"$2" -t "$3" "$1"
    fi
  }

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

    grep -iF -- "$query" "$all" > "$filtered" 2>/dev/null

    total=$(wc -l < "$filtered" | tr -d ' ')

    selected_num=1
    offset=1
    dirty=0
  }

  draw_vfind() {
    local rows list_height preview_height end preview_file search_status

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
      search_status="not searched yet"
    else
      search_status="searched"
    fi

    tput civis 2>/dev/null
    clear
    printf "\033[1;36mvfind lazy\033[0m  query: \033[1;33m%s\033[0m  matches: %s  \033[90m%s\033[0m\n" "$query" "$total" "$search_status"
    printf "\033[90mtype = edit | Tab = search | Enter = search/open | Ctrl+r = rescan | Esc = quit\033[0m\n\n"

    if [ "$dirty" -eq 1 ]; then
      echo "Press Tab or Enter to search."
      return
    fi

    if [ "$total" -eq 0 ]; then
      echo "No matching files."
      return
    fi

    awk -v start="$offset" -v end="$end" -v selected="$selected_num" '
      NR < start { next }
      NR > end { exit }
      NR == selected {
        printf "\033[7m%3s) %s\033[0m\n", NR, $0
        next
      }
      {
        printf "\033[1;32m%3s)\033[0m %s\n", NR, $0
      }
    ' "$filtered"

    preview_file=$(awk -v selected="$selected_num" 'NR == selected { print; exit }' "$filtered")

    printf "\n\033[1;36mPreview:\033[0m \033[1;32m%s\033[0m\n" "$preview_file"
    printf "\033[90m────────────────────────────────────────\033[0m\n"

    if [ -r "$preview_file" ] && LC_ALL=C grep -Iq '' "$preview_file" 2>/dev/null; then
      awk -v max="$preview_height" '
        NR <= max {
          printf "\033[90m%4d\033[0m  %s\n", NR, $0
        }
      ' "$preview_file"
    else
      echo "Binary file preview skipped."
    fi
  }

  while true; do
    draw_vfind

    local key rest file editor
    if ! read_vfind_key key; then
      cleanup_vfind
      clear
      return
    fi

    case "$key" in
      "")
        if [ "$dirty" -eq 1 ] || [ "$total" -eq 0 ]; then
          update_filter
          continue
        fi

        file=$(sed -n "${selected_num}p" "$filtered")
        cleanup_vfind

        editor="${EDITOR:-vim}"
        editor=$(vfind_editor)
        clear
        command $editor "$file"
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
        read_vfind_keys_timeout rest 2 1

        case "$rest" in
          "[A")
            [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
            ;;
          "[B")
            [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
            ;;
          *)
            cleanup_vfind
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

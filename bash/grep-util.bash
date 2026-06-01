gpick() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
gpick - lazy grep picker with preview using pure old Bash

Usage:
  gpick [initial search] [extensions] [directory]

Examples:
  gpick
  gpick defineProps vue,ts src
  gpick "case class" scala app
  gpick "TODO" "" .

Controls:
  Type text      Edit grep query only
  Tab            Search
  Enter          Search if changed, otherwise open selected file at first match
  Backspace      Delete character
  Ctrl+u         Clear query
  Ctrl+r         Rescan with the current query
  Down / Ctrl+n  Move down
  Up / Ctrl+p    Move up
  Esc            Quit

Notes:
  Pure Bash version. No fzf, no plugins, no mapfile, no ripgrep.
  Searches only when Tab, Enter, or Ctrl+r is pressed.
  Grep prunes .git, node_modules, vendor, dist, build, target, coverage,
  .next, .nuxt, .cache, tmp, and similar generated directories.
EOF
    return
  fi

  local query="${1:-}"
  local exts="${2:-}"
  local dir="${3:-.}"

  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gpick.XXXXXX") || return 1

  local filtered="$tmpdir/filtered"
  local selected_num=1
  local offset=1
  local total=0
  local dirty=1

  > "$filtered"

  cleanup_gpick() {
    tput cnorm 2>/dev/null
    rm -rf "$tmpdir"
  }

  gpick_editor() {
    if [ -n "${VISUAL:-}" ]; then
      printf "%s\n" "$VISUAL"
    elif [ -n "${EDITOR:-}" ]; then
      printf "%s\n" "$EDITOR"
    else
      printf "%s\n" "vim"
    fi
  }

  read_gpick_key() {
    if [ -n "${ZSH_VERSION:-}" ]; then
      IFS= read -rs -k 1 "$1"
    else
      IFS= read -rsn1 "$1"
    fi
  }

  read_gpick_keys_timeout() {
    if [ -n "${ZSH_VERSION:-}" ]; then
      IFS= read -rs -t "$3" -k "$2" "$1"
    else
      IFS= read -rsn"$2" -t "$3" "$1"
    fi
  }

  update_filter() {
    local old_ifs ext

    > "$filtered"

    if [ -z "$query" ]; then
      total=0
      selected_num=1
      offset=1
      dirty=0
      return
    fi

    if [ -z "$exts" ]; then
      find "$dir" \
        -type d \( -name .git -o -name .hg -o -name .svn -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target -o -name coverage -o -name .next -o -name .nuxt -o -name .cache -o -name .parcel-cache -o -name __pycache__ -o -name tmp -o -name temp \) -prune -o \
        -type f -exec grep -Il -- "$query" {} + 2>/dev/null \
        > "$filtered"
    else
      old_ifs="$IFS"
      IFS=","

      for ext in $exts; do
        ext="${ext// /}"
        ext="${ext#.}"

        [ -z "$ext" ] && continue

        find "$dir" \
          -type d \( -name .git -o -name .hg -o -name .svn -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target -o -name coverage -o -name .next -o -name .nuxt -o -name .cache -o -name .parcel-cache -o -name __pycache__ -o -name tmp -o -name temp \) -prune -o \
          -type f -name "*.$ext" -exec grep -Il -- "$query" {} + 2>/dev/null \
          >> "$filtered"
      done

      IFS="$old_ifs"
      sort -u "$filtered" -o "$filtered"
    fi

    total=$(wc -l < "$filtered" | tr -d ' ')

    if [ "$total" -eq 0 ]; then
      selected_num=1
      offset=1
      dirty=0
      return
    fi

    if [ "$selected_num" -gt "$total" ]; then
      selected_num="$total"
    fi

    if [ "$selected_num" -lt 1 ]; then
      selected_num=1
    fi

    dirty=0
  }

  draw_gpick() {
    local rows list_height preview_height end current_file preview_file search_status

    rows=$(tput lines 2>/dev/null || printf "24\n")

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

    printf "\033[1;36mgpick lazy\033[0m  grep: \033[1;33m%s\033[0m  matches: %s  \033[90m%s\033[0m\n" "$query" "$total" "$search_status"
    printf "\033[90mtype = edit | Tab = search | Enter = search/open | Ctrl+r = rescan | Esc = quit\033[0m\n\n"

    if [ "$dirty" -eq 1 ]; then
      printf "Press Tab or Enter to grep.\n"
      return
    fi

    if [ -z "$query" ]; then
      printf "Type a grep query, then press Tab or Enter.\n"
      return
    fi

    if [ "$total" -eq 0 ]; then
      printf "No matching files.\n"
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

    grep -n -C 3 --color=always -- "$query" "$preview_file" 2>/dev/null |
      head -n "$preview_height"
  }

  while true; do
    local key rest file editor line

    draw_gpick

    if ! read_gpick_key key; then
      cleanup_gpick
      clear
      return
    fi

    case "$key" in
      "")
        if [ "$dirty" -eq 1 ] || [ "$total" -eq 0 ]; then
          update_filter
          continue
        fi

        file=$(awk -v selected="$selected_num" 'NR == selected { print; exit }' "$filtered")
        line=$(grep -n -m 1 -- "$query" "$file" 2>/dev/null | cut -d: -f1)

        cleanup_gpick
        clear

        editor=$(gpick_editor)

        if printf "%s\n" "$editor" | grep -q "vim" && [ -n "$line" ]; then
          command $editor "+$line" "$file"
        else
          command $editor "$file"
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
        dirty=1
        update_filter
        ;;

      $'\016'|j)
        [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
        ;;

      $'\020'|k)
        [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
        ;;

      $'\033')
        read_gpick_keys_timeout rest 2 1

        case "$rest" in
          "[A")
            [ "$selected_num" -gt 1 ] && selected_num=$((selected_num - 1))
            ;;
          "[B")
            [ "$selected_num" -lt "$total" ] && selected_num=$((selected_num + 1))
            ;;
          *)
            cleanup_gpick
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

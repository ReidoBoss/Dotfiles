vvim() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
vvim - fake Neovim/NvChad-like explorer for plain Vim

Usage:
  vvim [directory]

Examples:
  vvim
  vvim src
  vvim ~/work/project

Controls:
  j / Down Arrow       Move down
  k / Up Arrow         Move up
  Enter / l / Right    Enter directory or open file
  h / Left             Go to parent directory
  f                    Find files using vfind
  g                    Grep project using gpick
  .                    Toggle hidden files
  p                    Toggle preview
  r                    Refresh
  o                    Open file by path
  n                    New file
  s                    Git status
  q / Esc              Quit

Notes:
  Pure Bash + Vim.
  No plugins. No fzf. No Neovim. No mapfile.
EOF
    return
  fi

  local cwd
  cwd=$(cd "${1:-.}" 2>/dev/null && pwd -P)

  if [ -z "$cwd" ]; then
    echo "Directory not found: ${1:-.}"
    return
  fi

  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/vvim.XXXXXX") || return

  local entries="$tmpdir/entries"
  local dirs="$tmpdir/dirs"
  local files="$tmpdir/files"
  local preview="$tmpdir/preview"

  local selected=1
  local offset=1
  local total=0

  local show_hidden=0
  local show_preview=1

  local entries_dirty=1
  local preview_dirty=1
  local git_dirty=1

  local preview_target=""
  local preview_width_cache=0
  local preview_height_cache=0

  local git_text="Git: none"

  cleanup_vvim() {
    tput cnorm 2>/dev/null
    rm -rf "$tmpdir"
  }

  vvim_editor() {
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

  read_vvim_key() {
    if [ -n "$ZSH_VERSION" ]; then
      IFS= read -rs -k 1 "$1"
    else
      IFS= read -rsn1 "$1"
    fi
  }

  read_vvim_key_timeout() {
    if [ -n "$ZSH_VERSION" ]; then
      IFS= read -rs -t "$2" -k 1 "$1"
    else
      IFS= read -rsn1 -t "$2" "$1"
    fi
  }

  mark_dirty() {
    entries_dirty=1
    preview_dirty=1
    git_dirty=1
  }

  refresh_git() {
    local branch changed_count

    if [ "$git_dirty" -eq 0 ]; then
      return
    fi

    if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
      changed_count=$(git -C "$cwd" status --short 2>/dev/null | wc -l | tr -d ' ')
      git_text="Git: $branch | changed: $changed_count"
    else
      git_text="Git: none"
    fi

    git_dirty=0
  }

  build_entries() {
    local p

    if [ "$entries_dirty" -eq 0 ]; then
      return
    fi

    > "$entries"
    > "$dirs"
    > "$files"

    if [ "$cwd" != "/" ]; then
      printf "%s\n" "$cwd/.." >> "$entries"
    fi

    for p in "$cwd"/*; do
      [ -e "$p" ] || [ -L "$p" ] || continue

      if [ -d "$p" ]; then
        printf "%s\n" "$p" >> "$dirs"
      elif [ -f "$p" ]; then
        printf "%s\n" "$p" >> "$files"
      fi
    done

    if [ "$show_hidden" -eq 1 ]; then
      for p in "$cwd"/.[!.]* "$cwd"/..?*; do
        [ -e "$p" ] || [ -L "$p" ] || continue

        if [ -d "$p" ]; then
          printf "%s\n" "$p" >> "$dirs"
        elif [ -f "$p" ]; then
          printf "%s\n" "$p" >> "$files"
        fi
      done
    fi

    sort -u "$dirs" >> "$entries"
    sort -u "$files" >> "$entries"

    total=$(wc -l < "$entries" | tr -d ' ')

    if [ "$total" -eq 0 ]; then
      selected=1
      offset=1
    fi

    if [ "$selected" -gt "$total" ]; then
      selected="$total"
    fi

    if [ "$selected" -lt 1 ]; then
      selected=1
    fi

    entries_dirty=0
    preview_dirty=1
  }

  display_name() {
    local item="$1"
    local base

    if [ "$item" = "$cwd/.." ]; then
      echo "../"
      return
    fi

    base=$(basename "$item")

    if [ -d "$item" ]; then
      echo "$base/"
    else
      echo "$base"
    fi
  }

  make_preview() {
    local target="$1"
    local max="$2"
    local width="$3"
    local p base

    if [ "$show_preview" -eq 0 ]; then
      > "$preview"
      echo "Preview disabled." >> "$preview"
      echo "" >> "$preview"
      echo "Press p to enable preview again." >> "$preview"
      preview_dirty=0
      return
    fi

    if [ "$preview_dirty" -eq 0 ] &&
       [ "$target" = "$preview_target" ] &&
       [ "$width" -eq "$preview_width_cache" ] &&
       [ "$max" -eq "$preview_height_cache" ]; then
      return
    fi

    > "$preview"

    preview_target="$target"
    preview_width_cache="$width"
    preview_height_cache="$max"

    if [ -z "$target" ]; then
      echo "No file selected." > "$preview"
      preview_dirty=0
      return
    fi

    if [ -d "$target" ]; then
      echo "Directory" >> "$preview"
      echo "" >> "$preview"

      local dir_preview="$tmpdir/preview-dir"
      > "$dir_preview"

      for p in "$target"/*; do
        [ -e "$p" ] || [ -L "$p" ] || continue
        base=$(basename "$p")

        if [ -d "$p" ]; then
          printf "[D] %s/\n" "$base" >> "$dir_preview"
        elif [ -f "$p" ]; then
          printf "    %s\n" "$base" >> "$dir_preview"
        fi
      done

      if [ "$show_hidden" -eq 1 ]; then
        for p in "$target"/.[!.]* "$target"/..?*; do
          [ -e "$p" ] || [ -L "$p" ] || continue
          base=$(basename "$p")

          if [ -d "$p" ]; then
            printf "[D] %s/\n" "$base" >> "$dir_preview"
          elif [ -f "$p" ]; then
            printf "    %s\n" "$base" >> "$dir_preview"
          fi
        done
      fi

      sort -u "$dir_preview" | head -n "$max" >> "$preview"
      rm -f "$dir_preview"

      preview_dirty=0
      return
    fi

    if [ ! -r "$target" ]; then
      echo "Cannot read file." > "$preview"
      preview_dirty=0
      return
    fi

    if LC_ALL=C grep -Iq '' "$target" 2>/dev/null; then
      awk -v max="$max" -v width="$width" '
        BEGIN {
          if (width < 30) width = 30
        }

        NR <= max {
          gsub(/\t/, "  ")

          line = $0
          limit = width - 8

          if (length(line) > limit) {
            line = substr(line, 1, limit - 3) "..."
          }

          printf "%4d  %s\n", NR, line
        }
      ' "$target" > "$preview"
    else
      echo "Binary file preview skipped." > "$preview"
    fi

    preview_dirty=0
  }

  draw_vvim() {
    local rows cols left_width right_col preview_width
    local list_start list_height preview_height
    local end i row item name text target line entry_index
    local hidden_text preview_text

    build_entries
    refresh_git

    rows=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 100)

    left_width=$((cols / 2))
    [ "$left_width" -lt 32 ] && left_width=32
    [ "$left_width" -gt 55 ] && left_width=55

    right_col=$((left_width + 3))
    preview_width=$((cols - right_col - 1))
    [ "$preview_width" -lt 30 ] && preview_width=30

    list_start=5
    list_height=$((rows - list_start - 1))
    [ "$list_height" -lt 8 ] && list_height=8

    preview_height=$((rows - list_start - 3))
    [ "$preview_height" -lt 8 ] && preview_height=8

    if [ "$selected" -lt "$offset" ]; then
      offset="$selected"
    fi

    if [ "$selected" -ge $((offset + list_height)) ]; then
      offset=$((selected - list_height + 1))
    fi

    end=$((offset + list_height - 1))
    [ "$end" -gt "$total" ] && end="$total"

    target=$(awk -v selected="$selected" 'NR == selected { print; exit }' "$entries")
    make_preview "$target" "$preview_height" "$preview_width"

    if [ "$show_hidden" -eq 1 ]; then
      hidden_text="on"
    else
      hidden_text="off"
    fi

    if [ "$show_preview" -eq 1 ]; then
      preview_text="on"
    else
      preview_text="off"
    fi

    tput civis 2>/dev/null
    clear

    tput cup 0 0
    printf "\033[1;36mvvim\033[0m  \033[1;33mfake NvChad for plain Vim\033[0m"

    tput cup 1 0
    printf "\033[90mPath: %s\033[0m" "$cwd"

    tput cup 2 0
    printf "\033[90m%s | hidden: %s | preview: %s\033[0m" "$git_text" "$hidden_text" "$preview_text"

    tput cup 3 0
    printf "\033[90mj/k/arrows move | Enter open | h/Left parent | f find | g grep | p preview | r refresh | q quit\033[0m"

    row=4
    while [ "$row" -lt "$rows" ]; do
      tput cup "$row" "$left_width"
      printf "\033[90m|\033[0m"
      row=$((row + 1))
    done

    tput cup 4 0
    printf "\033[1;32mExplorer\033[0m"

    tput cup 4 "$right_col"
    printf "\033[1;32mPreview\033[0m"

    i="$offset"
    row="$list_start"
    entry_index=0

    while IFS= read -r item; do
      entry_index=$((entry_index + 1))

      [ "$entry_index" -lt "$offset" ] && continue
      [ "$entry_index" -gt "$end" ] && break

      name=$(display_name "$item")

      if [ -d "$item" ]; then
        text="[D] $name"
      else
        text="    $name"
      fi

      tput cup "$row" 0

      if [ "$entry_index" -eq "$selected" ]; then
        printf "\033[7m%-*.*s\033[0m" "$left_width" "$left_width" "$text"
      else
        printf "%-*.*s" "$left_width" "$left_width" "$text"
      fi

      row=$((row + 1))
    done < "$entries"

    row=$((list_start + 1))

    while IFS= read -r line; do
      [ "$row" -ge "$rows" ] && break

      tput cup "$row" "$right_col"
      printf "%-*.*s" "$preview_width" "$preview_width" "$line"

      row=$((row + 1))
    done < "$preview"

    tput cup $((rows - 1)) 0
  }

  move_down() {
    if [ "$selected" -lt "$total" ]; then
      selected=$((selected + 1))
      preview_dirty=1
    fi
  }

  move_up() {
    if [ "$selected" -gt 1 ]; then
      selected=$((selected - 1))
      preview_dirty=1
    fi
  }

  open_selected() {
    local item

    item=$(awk -v selected="$selected" 'NR == selected { print; exit }' "$entries")

    if [ -z "$item" ]; then
      return
    fi

    if [ -d "$item" ]; then
      cwd=$(cd "$item" 2>/dev/null && pwd -P)
      selected=1
      offset=1
      mark_dirty
      return
    fi

    if [ -f "$item" ]; then
      local editor
      editor=$(vvim_editor)
      tput cnorm 2>/dev/null
      clear
      command $editor "$item"
      preview_dirty=1
      git_dirty=1
    fi
  }

  go_parent() {
    if [ "$cwd" != "/" ]; then
      cwd=$(cd "$cwd/.." 2>/dev/null && pwd -P)
      selected=1
      offset=1
      mark_dirty
    fi
  }

  open_by_path() {
    local file

    tput cnorm 2>/dev/null
    clear
    read -p "Open file: " file

    [ -z "$file" ] && return

    case "$file" in
      /*)
        tput cnorm 2>/dev/null
        command $(vvim_editor) "$file"
        ;;
      *)
        tput cnorm 2>/dev/null
        command $(vvim_editor) "$cwd/$file"
        ;;
    esac

    preview_dirty=1
    git_dirty=1
  }

  new_file() {
    local file full

    tput cnorm 2>/dev/null
    clear
    read -p "New file: " file

    [ -z "$file" ] && return

    case "$file" in
      /*)
        full="$file"
        ;;
      *)
        full="$cwd/$file"
        ;;
    esac

    mkdir -p "$(dirname "$full")"
    tput cnorm 2>/dev/null
    command $(vvim_editor) "$full"

    mark_dirty
  }

  show_git_status() {
    tput cnorm 2>/dev/null
    clear

    if ! git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a Git repository."
      echo
      read -p "Press Enter..."
      return
    fi

    printf "\033[1;36mGit status\033[0m\n\n"
    git -C "$cwd" status --short

    echo
    read -p "Press Enter..."

    git_dirty=1
  }

  while true; do
    local key k1 k2 rest

    draw_vvim

    if ! read_vvim_key key; then
      cleanup_vvim
      clear
      return
    fi

    case "$key" in
      q|Q)
        cleanup_vvim
        clear
        return
        ;;

      j)
        move_down
        ;;

      k)
        move_up
        ;;

      h|H)
        go_parent
        ;;

      l|L|"")
        open_selected
        ;;

      f|F)
        tput cnorm 2>/dev/null
        clear

        if command -v vfind >/dev/null 2>&1; then
          vfind "" "" "$cwd"
          mark_dirty
        else
          echo "vfind is not installed yet."
          read -p "Press Enter..."
        fi
        ;;

      g|G)
        tput cnorm 2>/dev/null
        clear

        if command -v gpick >/dev/null 2>&1; then
          gpick "" "" "$cwd"
          mark_dirty
        else
          echo "gpick is not installed yet."
          read -p "Press Enter..."
        fi
        ;;

      .)
        if [ "$show_hidden" -eq 1 ]; then
          show_hidden=0
        else
          show_hidden=1
        fi

        selected=1
        offset=1
        mark_dirty
        ;;

      p|P)
        if [ "$show_preview" -eq 1 ]; then
          show_preview=0
        else
          show_preview=1
        fi

        preview_dirty=1
        ;;

      r|R)
        mark_dirty
        ;;

      o|O)
        open_by_path
        ;;

      n|N)
        new_file
        ;;

      s|S)
        show_git_status
        ;;

      $'\033')
        read_vvim_key_timeout k1 1
        read_vvim_key_timeout k2 1

        rest="${k1}${k2}"

        case "$rest" in
          "[A"|OA)
            move_up
            ;;
          "[B"|OB)
            move_down
            ;;
          "[C"|OC)
            open_selected
            ;;
          "[D"|OD)
            go_parent
            ;;
          "")
            cleanup_vvim
            clear
            return
            ;;
        esac
        ;;
    esac
  done
}

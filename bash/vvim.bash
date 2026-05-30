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
  j / Down Arrow     Move down
  k / Up Arrow       Move up
  Enter / l / Right  Enter directory or open file
  h / Left           Go to parent directory
  f                  Find files using vfind
  g                  Grep project using gpick
  .                  Toggle hidden files
  r                  Refresh
  o                  Open file by path
  n                  New file
  s                  Git status
  q / Esc            Quit

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

  local entries="/tmp/vvim-entries-$$"
  local dirs="/tmp/vvim-dirs-$$"
  local files="/tmp/vvim-files-$$"
  local preview="/tmp/vvim-preview-$$"
  local selected=1
  local offset=1
  local show_hidden=0

  cleanup_vvim() {
    rm -f "$entries" "$dirs" "$files" "$preview"
  }

  build_entries() {
    local p

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
    local p base tmpdir

    > "$preview"

    if [ -z "$target" ]; then
      echo "No file selected." > "$preview"
      return
    fi

    if [ -d "$target" ]; then
      echo "Directory" >> "$preview"
      echo "" >> "$preview"

      tmpdir="/tmp/vvim-preview-dir-$$"
      > "$tmpdir"

      for p in "$target"/*; do
        [ -e "$p" ] || [ -L "$p" ] || continue
        base=$(basename "$p")

        if [ -d "$p" ]; then
          printf "[D] %s/\n" "$base" >> "$tmpdir"
        elif [ -f "$p" ]; then
          printf "    %s\n" "$base" >> "$tmpdir"
        fi
      done

      if [ "$show_hidden" -eq 1 ]; then
        for p in "$target"/.[!.]* "$target"/..?*; do
          [ -e "$p" ] || [ -L "$p" ] || continue
          base=$(basename "$p")

          if [ -d "$p" ]; then
            printf "[D] %s/\n" "$base" >> "$tmpdir"
          elif [ -f "$p" ]; then
            printf "    %s\n" "$base" >> "$tmpdir"
          fi
        done
      fi

      sort -u "$tmpdir" | head -n "$max" >> "$preview"
      rm -f "$tmpdir"
      return
    fi

    if [ ! -r "$target" ]; then
      echo "Cannot read file." > "$preview"
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
  }

  draw_vvim() {
    local rows cols left_width right_col preview_width
    local list_start list_height preview_height
    local total end i row item name text target line
    local branch changed_count hidden_text

    build_entries

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

    target=$(sed -n "${selected}p" "$entries")
    make_preview "$target" "$preview_height" "$preview_width"

    if [ "$show_hidden" -eq 1 ]; then
      hidden_text="on"
    else
      hidden_text="off"
    fi

    clear

    tput cup 0 0
    printf "\033[1;36mvvim\033[0m  \033[1;33mfake NvChad for plain Vim\033[0m"

    tput cup 1 0
    printf "\033[90mPath: %s\033[0m" "$cwd"

    tput cup 2 0
    if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
      changed_count=$(git -C "$cwd" status --short 2>/dev/null | wc -l | tr -d ' ')
      printf "\033[90mGit: %s | changed: %s | hidden: %s\033[0m" "$branch" "$changed_count" "$hidden_text"
    else
      printf "\033[90mGit: none | hidden: %s\033[0m" "$hidden_text"
    fi

    tput cup 3 0
    printf "\033[90mj/k move | Enter open | h parent | f find | g grep | . hidden | q quit\033[0m"

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

    while [ "$i" -le "$end" ]; do
      item=$(sed -n "${i}p" "$entries")
      name=$(display_name "$item")

      if [ -d "$item" ]; then
        text="[D] $name"
      else
        text="    $name"
      fi

      tput cup "$row" 0

      if [ "$i" -eq "$selected" ]; then
        printf "\033[7m%-*.*s\033[0m" "$left_width" "$left_width" "$text"
      else
        printf "%-*.*s" "$left_width" "$left_width" "$text"
      fi

      i=$((i + 1))
      row=$((row + 1))
    done

    row=$((list_start + 1))

    while IFS= read -r line; do
      [ "$row" -ge "$rows" ] && break

      tput cup "$row" "$right_col"
      printf "%-*.*s" "$preview_width" "$preview_width" "$line"

      row=$((row + 1))
    done < "$preview"

    tput cup $((rows - 1)) 0
  }

  open_selected() {
    local item

    item=$(sed -n "${selected}p" "$entries")

    if [ -z "$item" ]; then
      return
    fi

    if [ -d "$item" ]; then
      cwd=$(cd "$item" 2>/dev/null && pwd -P)
      selected=1
      offset=1
      return
    fi

    if [ -f "$item" ]; then
      clear
      vim "$item"
    fi
  }

  go_parent() {
    if [ "$cwd" != "/" ]; then
      cwd=$(cd "$cwd/.." 2>/dev/null && pwd -P)
      selected=1
      offset=1
    fi
  }

  open_by_path() {
    local file

    clear
    read -p "Open file: " file

    [ -z "$file" ] && return

    case "$file" in
      /*)
        vim "$file"
        ;;
      *)
        vim "$cwd/$file"
        ;;
    esac
  }

  new_file() {
    local file full

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
    vim "$full"
  }

  show_git_status() {
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
  }

  while true; do
    local key rest total

    draw_vvim

    total=$(wc -l < "$entries" | tr -d ' ')

    IFS= read -rsn1 key

    case "$key" in
      q|Q)
        cleanup_vvim
        clear
        return
        ;;

      j)
        [ "$selected" -lt "$total" ] && selected=$((selected + 1))
        ;;

      k)
        [ "$selected" -gt 1 ] && selected=$((selected - 1))
        ;;

      h|H)
        go_parent
        ;;

      l|L|"")
        open_selected
        ;;

      f|F)
        clear
        if command -v vfind >/dev/null 2>&1; then
          vfind "" "" "$cwd"
        else
          echo "vfind is not installed yet."
          read -p "Press Enter..."
        fi
        ;;

      g|G)
        clear
        if command -v gpick >/dev/null 2>&1; then
          gpick "" "" "$cwd"
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
        ;;

      r|R)
        :
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
        IFS= read -rsn2 -t 0.05 rest

        case "$rest" in
          "[A")
            [ "$selected" -gt 1 ] && selected=$((selected - 1))
            ;;
          "[B")
            [ "$selected" -lt "$total" ] && selected=$((selected + 1))
            ;;
          "[C")
            open_selected
            ;;
          "[D")
            go_parent
            ;;
          *)
            cleanup_vvim
            clear
            return
            ;;
        esac
        ;;
    esac
  done
}

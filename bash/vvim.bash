vtodo() {
  tmp="/tmp/vtodo-$$"

  grep -RIn \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=dist \
    --exclude-dir=build \
    --exclude-dir=target \
    -E "TODO|FIXME|HACK|NOTE|BUG" . > "$tmp" 2>/dev/null

  if [ ! -s "$tmp" ]; then
    echo "No TODO/FIXME/HACK/NOTE/BUG found."
    rm -f "$tmp"
    read -p "Press Enter..."
    return
  fi

  selected=1
  offset=1
  total=$(wc -l < "$tmp" | tr -d ' ')

  while true; do
    rows=$(tput lines 2>/dev/null || echo 24)
    list_height=$((rows - 6))
    [ "$list_height" -lt 5 ] && list_height=5

    [ "$selected" -lt "$offset" ] && offset="$selected"
    [ "$selected" -ge $((offset + list_height)) ] && offset=$((selected - list_height + 1))

    end=$((offset + list_height - 1))
    [ "$end" -gt "$total" ] && end="$total"

    clear
    printf "\033[1;36mvtodo\033[0m  matches: %s\n" "$total"
    printf "\033[90mj/k or arrows = move | Enter = open | q = quit\033[0m\n\n"

    i="$offset"

    while [ "$i" -le "$end" ]; do
      line=$(sed -n "${i}p" "$tmp")

      if [ "$i" -eq "$selected" ]; then
        printf "\033[7m%3s) %s\033[0m\n" "$i" "$line"
      else
        printf "\033[1;32m%3s)\033[0m %s\n" "$i" "$line"
      fi

      i=$((i + 1))
    done

    IFS= read -rsn1 key

    case "$key" in
      q|Q)
        rm -f "$tmp"
        return
        ;;

      j)
        [ "$selected" -lt "$total" ] && selected=$((selected + 1))
        ;;

      k)
        [ "$selected" -gt 1 ] && selected=$((selected - 1))
        ;;

      "")
        match=$(sed -n "${selected}p" "$tmp")
        file=$(echo "$match" | cut -d: -f1)
        line_no=$(echo "$match" | cut -d: -f2)

        rm -f "$tmp"
        vim "+$line_no" "$file"
        return
        ;;

      $'\033')
        IFS= read -rsn2 rest

        case "$rest" in
          "[A")
            [ "$selected" -gt 1 ] && selected=$((selected - 1))
            ;;
          "[B")
            [ "$selected" -lt "$total" ] && selected=$((selected + 1))
            ;;
        esac
        ;;
    esac
  done
}

vchanged() {
  tmp="/tmp/vchanged-$$"

  git status --short 2>/dev/null | awk '{print $2}' > "$tmp"

  if [ ! -s "$tmp" ]; then
    echo "No changed files."
    rm -f "$tmp"
    read -p "Press Enter..."
    return
  fi

  selected=1
  offset=1
  total=$(wc -l < "$tmp" | tr -d ' ')

  while true; do
    rows=$(tput lines 2>/dev/null || echo 24)

    list_height=$((rows / 2 - 4))
    [ "$list_height" -lt 5 ] && list_height=5

    preview_height=$((rows - list_height - 8))
    [ "$preview_height" -lt 5 ] && preview_height=5

    [ "$selected" -lt "$offset" ] && offset="$selected"
    [ "$selected" -ge $((offset + list_height)) ] && offset=$((selected - list_height + 1))

    end=$((offset + list_height - 1))
    [ "$end" -gt "$total" ] && end="$total"

    clear
    printf "\033[1;36mvchanged\033[0m  changed files: %s\n" "$total"
    printf "\033[90mj/k or arrows = move | Enter = open | q = quit\033[0m\n\n"

    i="$offset"

    while [ "$i" -le "$end" ]; do
      file=$(sed -n "${i}p" "$tmp")

      if [ "$i" -eq "$selected" ]; then
        printf "\033[7m%3s) %s\033[0m\n" "$i" "$file"
      else
        printf "\033[1;32m%3s)\033[0m %s\n" "$i" "$file"
      fi

      i=$((i + 1))
    done

    file=$(sed -n "${selected}p" "$tmp")

    printf "\n\033[1;36mDiff preview:\033[0m \033[1;32m%s\033[0m\n" "$file"
    printf "\033[90m────────────────────────────────────────\033[0m\n"

    git diff -- "$file" 2>/dev/null | head -n "$preview_height"

    IFS= read -rsn1 key

    case "$key" in
      q|Q)
        rm -f "$tmp"
        return
        ;;

      j)
        [ "$selected" -lt "$total" ] && selected=$((selected + 1))
        ;;

      k)
        [ "$selected" -gt 1 ] && selected=$((selected - 1))
        ;;

      "")
        file=$(sed -n "${selected}p" "$tmp")
        rm -f "$tmp"
        vim "$file"
        return
        ;;

      $'\033')
        IFS= read -rsn2 rest

        case "$rest" in
          "[A")
            [ "$selected" -gt 1 ] && selected=$((selected - 1))
            ;;
          "[B")
            [ "$selected" -lt "$total" ] && selected=$((selected + 1))
            ;;
        esac
        ;;
    esac
  done
}
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

vfind() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
vfind - live file finder with preview using pure old Bash

Usage:
  vfind [initial query] [extensions] [directory]

Examples:
  vfind
  vfind UserService
  vfind Button vue,ts src
  vfind controller scala,java app

Controls:
  Type text      Filter files live
  Backspace      Delete character
  Ctrl+u         Clear search
  Down / Ctrl+n  Move down
  Up / Ctrl+p    Move up
  Enter          Open selected file
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

  local all="/tmp/vfind-all-$$"
  local filtered="/tmp/vfind-filtered-$$"

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
    if [ -z "$query" ]; then
      cat "$all" > "$filtered"
    else
      grep -iF -- "$query" "$all" > "$filtered" 2>/dev/null
    fi

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

  draw_vfind() {
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

    printf "\033[1;36mvfind live\033[0m  query: \033[1;33m%s\033[0m  matches: %s\n" "$query" "$total"
    printf "\033[90mtype = filter | arrows/Ctrl+n/Ctrl+p = move | Ctrl+u = clear | Enter = open | Esc = quit\033[0m\n\n"

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

    if [ ! -r "$preview_file" ]; then
      echo "Cannot read file."
      return
    fi

    if LC_ALL=C grep -Iq '' "$preview_file" 2>/dev/null; then
      awk -v max="$preview_height" '
        NR <= max {
          printf "\033[90m%4d\033[0m  %s\n", NR, $0
        }
      ' "$preview_file"
    else
      echo "Binary file preview skipped."
    fi
  }

  update_filter

  while true; do
    draw_vfind

    local key rest file editor

    IFS= read -rsn1 key

    case "$key" in
      "")
        if [ "$total" -eq 0 ]; then
          continue
        fi

        file=$(sed -n "${selected_num}p" "$filtered")
        rm -f "$all" "$filtered"

        editor="${EDITOR:-vim}"
        clear
        "$editor" "$file"
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

vvim() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
vvim - fake Neovim dashboard for plain Vim

Usage:
  vvim

Controls:
  j / Down Arrow   Move down
  k / Up Arrow     Move up
  Enter            Run selected action
  f                Find files
  g                Grep project
  t                TODO/FIXME picker
  c                Changed git files
  o                Open file by path
  l                Open file:line
  n                New file
  e                Vim file explorer
  s                Git status
  ? / h            Toggle help
  r                Redraw
  q                Quit

Notes:
  Pure Bash + Vim.
  No plugins. No fzf. No Neovim. No mapfile.
EOF
    return
  fi

  local selected=1
  local total=10
  local show_help=0

  vvim_label() {
    case "$1" in
      1) echo "Find files" ;;
      2) echo "Grep project" ;;
      3) echo "TODO / FIXME / HACK / NOTE" ;;
      4) echo "Changed Git files" ;;
      5) echo "Open file by path" ;;
      6) echo "Open file:line" ;;
      7) echo "New file" ;;
      8) echo "Vim file explorer" ;;
      9) echo "Git status" ;;
      10) echo "Quit" ;;
    esac
  }

  vvim_key() {
    case "$1" in
      1) echo "f" ;;
      2) echo "g" ;;
      3) echo "t" ;;
      4) echo "c" ;;
      5) echo "o" ;;
      6) echo "l" ;;
      7) echo "n" ;;
      8) echo "e" ;;
      9) echo "s" ;;
      10) echo "q" ;;
    esac
  }

  vvim_desc() {
    case "$1" in
      1)
        cat <<'EOF'
Search files by filename/path.

Uses:
  vfind

Good for:
  UserService
  Button.vue
  routes
  controller
EOF
        ;;
      2)
        cat <<'EOF'
Search inside files with live grep.

Uses:
  gpick

Good for:
  function names
  class names
  TODO text
  error messages
EOF
        ;;
      3)
        cat <<'EOF'
Find project comments.

Searches:
  TODO
  FIXME
  HACK
  NOTE
  BUG

Opens Vim at the selected line.
EOF
        ;;
      4)
        cat <<'EOF'
Show changed Git files.

Useful before committing.
Shows diff preview if your vchanged supports it.
EOF
        ;;
      5)
        cat <<'EOF'
Open a file by typing its path.

Example:
  src/main/scala/UserService.scala
EOF
        ;;
      6)
        cat <<'EOF'
Open file at line number.

Example:
  src/main/scala/UserService.scala:42

Very useful for compiler errors.
EOF
        ;;
      7)
        cat <<'EOF'
Create a new file and open it.

Automatically creates parent folders.

Example:
  src/features/user/UserService.scala
EOF
        ;;
      8)
        cat <<'EOF'
Open Vim's built-in file explorer.

This uses plain Vim netrw:

  vim .

No plugins needed.
EOF
        ;;
      9)
        cat <<'EOF'
Show Git status.

Useful for quickly checking modified,
added, deleted, or untracked files.
EOF
        ;;
      10)
        cat <<'EOF'
Exit vvim.
EOF
        ;;
    esac
  }

  vvim_pause() {
    echo
    read -p "Press Enter to continue..."
  }

  vvim_missing() {
    clear
    echo "$1 is not installed yet."
    echo
    echo "Add the $1 function to your shell config first."
    vvim_pause
  }

  vvim_open_file_line() {
    local input file line

    clear
    read -p "File:line: " input

    [ -z "$input" ] && return

    file="${input%%:*}"
    line="${input##*:}"

    if [ ! -f "$file" ]; then
      echo "File not found: $file"
      vvim_pause
      return
    fi

    case "$line" in
      ''|*[!0-9]*)
        vim "$file"
        ;;
      *)
        vim "+$line" "$file"
        ;;
    esac
  }

  vvim_git_status() {
    clear

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a Git repository."
      vvim_pause
      return
    fi

    printf "\033[1;36mGit status\033[0m\n\n"
    git status --short

    echo
    printf "\033[1;36mBranch:\033[0m "
    git rev-parse --abbrev-ref HEAD 2>/dev/null

    vvim_pause
  }

  vvim_run() {
    local choice="$1"
    local file input

    case "$choice" in
      1)
        if command -v vfind >/dev/null 2>&1; then
          vfind
        else
          vvim_missing "vfind"
        fi
        ;;
      2)
        if command -v gpick >/dev/null 2>&1; then
          gpick
        else
          vvim_missing "gpick"
        fi
        ;;
      3)
        if command -v vtodo >/dev/null 2>&1; then
          vtodo
        else
          vvim_missing "vtodo"
        fi
        ;;
      4)
        if command -v vchanged >/dev/null 2>&1; then
          vchanged
        else
          vvim_missing "vchanged"
        fi
        ;;
      5)
        clear
        read -p "File path: " file
        [ -n "$file" ] && vim "$file"
        ;;
      6)
        vvim_open_file_line
        ;;
      7)
        clear
        read -p "New file path: " file

        if [ -n "$file" ]; then
          mkdir -p "$(dirname "$file")"
          vim "$file"
        fi
        ;;
      8)
        vim .
        ;;
      9)
        vvim_git_status
        ;;
      10)
        clear
        return 1
        ;;
    esac

    return 0
  }

  vvim_draw() {
    local i label key branch changed_count rows cols

    rows=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)

    clear

    printf "\033[1;36m"
    echo " __     ___"
    echo " \ \   / (_)  ___  ___"
    echo "  \ \ / /| | / _ \/ __|"
    echo "   \ V / | ||  __/\__ \\"
    echo "    \_/  |_| \___||___/"
    printf "\033[0m"

    printf "\033[1;33mFake Neovim for plain Vim\033[0m\n"
    printf "\033[90mProject: %s\033[0m\n" "$(pwd)"

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      changed_count=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
      printf "\033[90mGit: %s | changed files: %s\033[0m\n" "$branch" "$changed_count"
    else
      printf "\033[90mGit: not a repository\033[0m\n"
    fi

    printf "\n"
    printf "\033[90mj/k or arrows = move | Enter = run | ? = help | q = quit\033[0m\n"
    printf "\033[90m------------------------------------------------------------\033[0m\n\n"

    i=1

    while [ "$i" -le "$total" ]; do
      label=$(vvim_label "$i")
      key=$(vvim_key "$i")

      if [ "$i" -eq "$selected" ]; then
        printf "\033[7m  [%s] %-36s\033[0m\n" "$key" "$label"
      else
        printf "  \033[1;32m[%s]\033[0m %-36s\n" "$key" "$label"
      fi

      i=$((i + 1))
    done

    printf "\n\033[90m------------------------------------------------------------\033[0m\n"
    printf "\033[1;36mDetails:\033[0m \033[1;32m%s\033[0m\n\n" "$(vvim_label "$selected")"

    vvim_desc "$selected"

    if [ "$show_help" -eq 1 ]; then
      printf "\n\033[90m------------------------------------------------------------\033[0m\n"
      printf "\033[1;36mHelp:\033[0m\n"
      echo "  f  find files"
      echo "  g  grep project"
      echo "  t  todo picker"
      echo "  c  changed files"
      echo "  o  open file"
      echo "  l  open file:line"
      echo "  n  new file"
      echo "  e  file explorer"
      echo "  s  git status"
      echo "  q  quit"
    fi
  }

  while true; do
    local key rest

    vvim_draw

    IFS= read -rsn1 key

    case "$key" in
      q|Q)
        clear
        return
        ;;

      j)
        [ "$selected" -lt "$total" ] && selected=$((selected + 1))
        ;;

      k)
        [ "$selected" -gt 1 ] && selected=$((selected - 1))
        ;;

      "")
        vvim_run "$selected" || return
        ;;

      f|F)
        vvim_run 1 || return
        ;;

      g|G)
        vvim_run 2 || return
        ;;

      t|T)
        vvim_run 3 || return
        ;;

      c|C)
        vvim_run 4 || return
        ;;

      o|O)
        vvim_run 5 || return
        ;;

      l|L)
        vvim_run 6 || return
        ;;

      n|N)
        vvim_run 7 || return
        ;;

      e|E)
        vvim_run 8 || return
        ;;

      s|S)
        vvim_run 9 || return
        ;;

      h|H|\?)
        if [ "$show_help" -eq 1 ]; then
          show_help=0
        else
          show_help=1
        fi
        ;;

      r|R)
        :
        ;;

      $'\033')
        IFS= read -rsn2 rest

        case "$rest" in
          "[A")
            [ "$selected" -gt 1 ] && selected=$((selected - 1))
            ;;
          "[B")
            [ "$selected" -lt "$total" ] && selected=$((selected + 1))
            ;;
        esac
        ;;
    esac
  done
}

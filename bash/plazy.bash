plazy() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
plazy - fake lazygit-like Perforce TUI for Git users

Usage:
  plazy [path]

Examples:
  plazy
  plazy src

Controls:
  j / Down Arrow       Move down
  k / Up Arrow         Move up
  h / l / Tab          Switch panels
  Enter / o            Open selected file in editor
  d                    Preview diff or changelist description
  e                    p4 edit selected file
  a                    p4 reconcile selected path, or workspace when no file is selected
  s                    p4 sync selected path, or workspace when no file is selected
  R                    p4 revert selected file after confirmation
  c                    Create pending changelist
  C                    Move selected file to changelist
  S                    Submit selected changelist after confirmation
  r                    Refresh
  ?                    Show help
  q / Esc              Quit

Notes:
  Requires the Perforce p4 CLI to be installed and configured by your company.
  This does not replace p4 credentials, tickets, client specs, or workspace setup.
  It wraps common p4 commands in a keyboard-driven fake TUI.

Git-to-Perforce translation:
  git pull       -> p4 sync
  git checkout   -> p4 edit
  git discard    -> p4 revert
  git stage      -> p4 reopen -c <change>
  git commit     -> p4 submit -c <change>
EOF
    return
  fi

  if ! command -v p4 >/dev/null 2>&1; then
    printf "plazy: p4 was not found in PATH.\n" >&2
    printf "Ask your company how they install Perforce Helix Core CLI, then run p4 info.\n" >&2
    return 1
  fi

  local root
  root=$(cd "${1:-.}" 2>/dev/null && pwd -P)

  if [ -z "$root" ]; then
    printf "plazy: path not found: %s\n" "${1:-.}" >&2
    return 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/plazy.XXXXXX") || return 1

  local opened="$tmpdir/opened"
  local changes="$tmpdir/changes"
  local preview="$tmpdir/preview"
  local info="$tmpdir/info"
  local selected_file=1
  local selected_change=1
  local file_total=0
  local change_total=0
  local panel=files
  local message="Ready."

  cleanup_plazy() {
    tput cnorm 2>/dev/null
    rm -rf "$tmpdir"
  }

  plazy_editor() {
    if [ -n "${VISUAL:-}" ]; then
      printf "%s\n" "$VISUAL"
    elif [ -n "${EDITOR:-}" ]; then
      printf "%s\n" "$EDITOR"
    else
      printf "%s\n" "vim"
    fi
  }

  read_plazy_key() {
    if [ -n "${ZSH_VERSION:-}" ]; then
      IFS= read -rs -k 1 "$1"
    else
      IFS= read -rsn1 "$1"
    fi
  }

  read_plazy_key_timeout() {
    if [ -n "${ZSH_VERSION:-}" ]; then
      IFS= read -rs -t "$2" -k 1 "$1"
    else
      IFS= read -rsn1 -t "$2" "$1"
    fi
  }

  confirm_plazy() {
    local prompt="$1"
    local answer

    tput cnorm 2>/dev/null
    printf "\n%s [y/N] " "$prompt"
    IFS= read -r answer

    case "$answer" in
      y|Y|yes|YES)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }

  show_help() {
    tput cnorm 2>/dev/null
    clear
    cat <<'EOF'
plazy bindings

Navigation:
  j / Down       move down
  k / Up         move up
  h / l / Tab    switch panels
  q / Esc        quit
  ?              show this help

Files:
  Enter / o      open selected file in editor
  d              preview diff
  e              p4 edit selected file
  a              p4 reconcile selected path, or workspace when no file is selected
  s              p4 sync selected path, or workspace when no file is selected
  R              p4 revert selected file after confirmation

Changelists:
  c              create pending changelist
  C              move selected file to changelist
  S              submit selected changelist after confirmation

Aliases kept for convenience:
  m              move selected file to changelist
  u              submit selected changelist
  v              revert selected file

Perforce mental model:
  git pull       -> p4 sync
  git checkout   -> p4 edit
  git discard    -> p4 revert
  git stage      -> p4 reopen -c <change>
  git commit     -> p4 submit -c <change>
EOF
    printf "\nPress Enter..."
    IFS= read -r _
    message="Returned from help."
  }

  selected_opened_file() {
    awk -v selected="$selected_file" 'NR == selected {
      split($0, parts, "#")
      print parts[1]
      exit
    }' "$opened"
  }

  local_path_for_file() {
    local file="$1"

    (
      cd "$root" || exit 1
      p4 where "$file" 2>/dev/null
    ) | awk 'NR == 1 {
      local_path = $0
      sub(/^[^ ]+ /, "", local_path)
      sub(/^[^ ]+ /, "", local_path)
      print local_path
      exit
    }'
  }

  selected_change_id() {
    awk -v selected="$selected_change" 'NR == selected {
      print $2
      exit
    }' "$changes"
  }

  refresh_plazy() {
    (
      cd "$root" || exit 1
      p4 opened ... 2>&1
    ) > "$opened"

    if grep -q "File(s) not opened on this client" "$opened" 2>/dev/null; then
      > "$opened"
    fi

    (
      cd "$root" || exit 1
      p4 changes -s pending -u "${P4USER:-}" ... 2>/dev/null
    ) > "$changes"

    if [ ! -s "$changes" ]; then
      (
        cd "$root" || exit 1
        p4 changes -s pending ... 2>/dev/null
      ) > "$changes"
    fi

    (
      cd "$root" || exit 1
      p4 info 2>&1
    ) > "$info"

    file_total=$(wc -l < "$opened" | tr -d ' ')
    change_total=$(wc -l < "$changes" | tr -d ' ')

    [ "$selected_file" -lt 1 ] && selected_file=1
    [ "$selected_change" -lt 1 ] && selected_change=1
    [ "$selected_file" -gt "$file_total" ] && selected_file="$file_total"
    [ "$selected_change" -gt "$change_total" ] && selected_change="$change_total"
    [ "$selected_file" -lt 1 ] && selected_file=1
    [ "$selected_change" -lt 1 ] && selected_change=1
  }

  update_preview() {
    local file change

    > "$preview"

    if [ "$panel" = files ]; then
      file=$(selected_opened_file)

      if [ -z "$file" ]; then
        printf "No opened files.\n\nUse a to run p4 reconcile, or e on a path after opening a file from outside plazy.\n" > "$preview"
        return
      fi

      (
        cd "$root" || exit 1
        printf "Diff: %s\n\n" "$file"
        p4 diff -du "$file" 2>&1
      ) > "$preview"
      return
    fi

    change=$(selected_change_id)

    if [ -z "$change" ]; then
      printf "No pending changelists.\n\nUse c to create one.\n" > "$preview"
      return
    fi

    (
      cd "$root" || exit 1
      p4 describe -s "$change" 2>&1
    ) > "$preview"
  }

  draw_plazy() {
    local rows cols left_width right_col list_height preview_height
    local row end i line

    refresh_plazy
    update_preview

    rows=$(tput lines 2>/dev/null || printf "24\n")
    cols=$(tput cols 2>/dev/null || printf "100\n")

    left_width=$((cols / 2))
    [ "$left_width" -lt 38 ] && left_width=38
    [ "$left_width" -gt 70 ] && left_width=70

    right_col=$((left_width + 3))
    list_height=$((rows - 9))
    [ "$list_height" -lt 8 ] && list_height=8
    preview_height=$((rows - 7))
    [ "$preview_height" -lt 8 ] && preview_height=8

    tput civis 2>/dev/null
    clear

    tput cup 0 0
    printf "\033[1;36mplazy\033[0m  \033[1;33mfake lazygit for Perforce, written for Git users\033[0m"

    tput cup 1 0
    printf "\033[90mRoot: %s\033[0m" "$root"

    tput cup 2 0
    awk 'NR <= 2 { printf "\033[90m%s\033[0m\n", $0 }' "$info"

    tput cup 4 0
    printf "\033[90mh/l panel | j/k move | Enter open | d diff | e checkout/edit | s pull/sync | R discard/revert | C stage/change | S commit/submit | ? help\033[0m"

    row=5
    while [ "$row" -lt "$rows" ]; do
      tput cup "$row" "$left_width"
      printf "\033[90m|\033[0m"
      row=$((row + 1))
    done

    tput cup 6 0
    if [ "$panel" = files ]; then
      printf "\033[7mChanged Files / Opened Files (%s)\033[0m" "$file_total"
    else
      printf "\033[1;32mChanged Files / Opened Files (%s)\033[0m" "$file_total"
    fi

    tput cup 6 "$right_col"
    printf "\033[1;32mPreview\033[0m"

    end="$list_height"
    i=1
    row=7

    while IFS= read -r line; do
      [ "$i" -gt "$end" ] && break
      tput cup "$row" 0

      if [ "$panel" = files ] && [ "$i" -eq "$selected_file" ]; then
        printf "\033[7m%-*.*s\033[0m" "$left_width" "$left_width" "$line"
      else
        printf "%-*.*s" "$left_width" "$left_width" "$line"
      fi

      i=$((i + 1))
      row=$((row + 1))
    done < "$opened"

    row=$((7 + list_height / 2))
    tput cup "$row" 0

    if [ "$panel" = changes ]; then
      printf "\033[7mPending Changelists / Commits (%s)\033[0m" "$change_total"
    else
      printf "\033[1;32mPending Changelists / Commits (%s)\033[0m" "$change_total"
    fi

    row=$((row + 1))
    i=1

    while IFS= read -r line; do
      [ "$row" -ge $((rows - 2)) ] && break
      tput cup "$row" 0

      if [ "$panel" = changes ] && [ "$i" -eq "$selected_change" ]; then
        printf "\033[7m%-*.*s\033[0m" "$left_width" "$left_width" "$line"
      else
        printf "%-*.*s" "$left_width" "$left_width" "$line"
      fi

      i=$((i + 1))
      row=$((row + 1))
    done < "$changes"

    row=7
    i=1

    while IFS= read -r line; do
      [ "$i" -gt "$preview_height" ] && break
      [ "$row" -ge "$rows" ] && break
      tput cup "$row" "$right_col"
      printf "%-*.*s" "$((cols - right_col - 1))" "$((cols - right_col - 1))" "$line"
      i=$((i + 1))
      row=$((row + 1))
    done < "$preview"

    tput cup $((rows - 1)) 0
    printf "\033[90m%s\033[0m" "$message"
  }

  run_p4_action() {
    local label="$1"
    shift

    tput cnorm 2>/dev/null
    clear

    (
      cd "$root" || exit 1
      "$@"
    )

    message="$label finished."
    printf "\nPress Enter..."
    IFS= read -r _
  }

  create_change() {
    local desc tmp

    tput cnorm 2>/dev/null
    clear
    printf "Changelist description: "
    IFS= read -r desc

    if [ -z "$desc" ]; then
      message="Changelist creation cancelled."
      return
    fi

    tmp="$tmpdir/change-spec"

    (
      cd "$root" || exit 1
      p4 change -o
    ) > "$tmp" || {
      message="Could not create changelist spec."
      return
    }

    awk -v desc="$desc" '
      BEGIN { in_desc = 0; wrote_desc = 0 }
      /^Description:/ {
        print
        print "\t" desc
        in_desc = 1
        wrote_desc = 1
        next
      }
      in_desc && /^\t/ { next }
      in_desc {
        in_desc = 0
      }
      { print }
      END {
        if (!wrote_desc) {
          print "Description:"
          print "\t" desc
        }
      }
    ' "$tmp" > "$tmp.new"

    tput cnorm 2>/dev/null
    clear

    (
      cd "$root" || exit 1
      p4 change -i < "$tmp.new"
    )

    message="Create changelist finished."
    printf "\nPress Enter..."
    IFS= read -r _
  }

  move_file_to_change() {
    local file change

    file=$(selected_opened_file)

    if [ -z "$file" ]; then
      message="No opened file selected."
      return
    fi

    tput cnorm 2>/dev/null
    clear
    printf "Move file to changelist number: "
    IFS= read -r change

    if [ -z "$change" ]; then
      message="Move cancelled."
      return
    fi

    run_p4_action "Move file" p4 reopen -c "$change" "$file"
  }

  submit_change() {
    local change

    change=$(selected_change_id)

    if [ -z "$change" ]; then
      message="No pending changelist selected."
      return
    fi

    if confirm_plazy "Submit changelist $change?"; then
      run_p4_action "Submit changelist" p4 submit -c "$change"
    else
      message="Submit cancelled."
    fi
  }

  open_selected_file() {
    local file local_file editor

    file=$(selected_opened_file)

    if [ -z "$file" ]; then
      message="No opened file selected."
      return
    fi

    local_file=$(local_path_for_file "$file")
    [ -z "$local_file" ] && local_file="$file"

    editor=$(plazy_editor)
    tput cnorm 2>/dev/null
    clear
    command $editor "$local_file"
    message="Returned from editor."
  }

  refresh_plazy

  while true; do
    local key k1 k2 rest file

    draw_plazy

    if ! read_plazy_key key; then
      cleanup_plazy
      clear
      return
    fi

    case "$key" in
      q|Q)
        cleanup_plazy
        clear
        return
        ;;

      r)
        message="Refreshed."
        ;;

      h|H|l|L|$'\t')
        if [ "$panel" = files ]; then
          panel=changes
        else
          panel=files
        fi
        ;;

      j)
        if [ "$panel" = files ]; then
          [ "$selected_file" -lt "$file_total" ] && selected_file=$((selected_file + 1))
        else
          [ "$selected_change" -lt "$change_total" ] && selected_change=$((selected_change + 1))
        fi
        ;;

      k)
        if [ "$panel" = files ]; then
          [ "$selected_file" -gt 1 ] && selected_file=$((selected_file - 1))
        else
          [ "$selected_change" -gt 1 ] && selected_change=$((selected_change - 1))
        fi
        ;;

      d|D)
        message="Preview updated."
        ;;

      e|E)
        file=$(selected_opened_file)
        if [ -n "$file" ]; then
          run_p4_action "Edit" p4 edit "$file"
        else
          message="No file selected."
        fi
        ;;

      a|A)
        file=$(selected_opened_file)
        if [ -n "$file" ]; then
          run_p4_action "Reconcile" p4 reconcile "$file"
        else
          run_p4_action "Reconcile workspace" p4 reconcile ...
        fi
        ;;

      R)
        file=$(selected_opened_file)
        if [ -z "$file" ]; then
          message="No file selected."
        elif confirm_plazy "Revert $file?"; then
          run_p4_action "Revert" p4 revert "$file"
        else
          message="Revert cancelled."
        fi
        ;;

      v|V)
        file=$(selected_opened_file)
        if [ -z "$file" ]; then
          message="No file selected."
        elif confirm_plazy "Revert $file?"; then
          run_p4_action "Revert" p4 revert "$file"
        else
          message="Revert cancelled."
        fi
        ;;

      s)
        file=$(selected_opened_file)
        if [ -n "$file" ]; then
          run_p4_action "Sync" p4 sync "$file"
        else
          run_p4_action "Sync workspace" p4 sync ...
        fi
        ;;

      c)
        create_change
        ;;

      C|m|M)
        move_file_to_change
        ;;

      S|u|U)
        submit_change
        ;;

      "?")
        show_help
        ;;

      o|O|"")
        open_selected_file
        ;;

      $'\033')
        read_plazy_key_timeout k1 1
        read_plazy_key_timeout k2 1
        rest="${k1}${k2}"

        case "$rest" in
          "[A"|OA)
            if [ "$panel" = files ]; then
              [ "$selected_file" -gt 1 ] && selected_file=$((selected_file - 1))
            else
              [ "$selected_change" -gt 1 ] && selected_change=$((selected_change - 1))
            fi
            ;;
          "[B"|OB)
            if [ "$panel" = files ]; then
              [ "$selected_file" -lt "$file_total" ] && selected_file=$((selected_file + 1))
            else
              [ "$selected_change" -lt "$change_total" ] && selected_change=$((selected_change + 1))
            fi
            ;;
          "")
            cleanup_plazy
            clear
            return
            ;;
        esac
        ;;
    esac
  done
}

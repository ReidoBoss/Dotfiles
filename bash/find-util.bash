vfind() {
  local source_file source_dir

  source_file="${BASH_SOURCE[0]}"
  source_dir=$(cd "$(dirname "$source_file")" 2>/dev/null && pwd -P)

  if [ -z "$source_dir" ] || [ ! -r "$source_dir/vfind.bash" ]; then
    printf "vfind: cannot load vfind.bash next to find-util.bash.\n" >&2
    return 1
  fi

  . "$source_dir/vfind.bash"
  vfind "$@"
}

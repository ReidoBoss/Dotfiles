vvim() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
vvim - fake NvChad-like TUI using plain Vim only

Usage:
  vvim [path]

Examples:
  vvim
  vvim src
  vvim README.md

Controls:
  Space e        Toggle the folder tree
  Space f f      Find files with Vim quickfix, unless focused in the tree
  Space f w      Grep project with grep + find pruning, unless focused in the tree
  Space f r      Recent files under the current project
  Space b        Open listed buffers through quickfix
  Space h        Open vvim help/dashboard
  Space q        Close quickfix
  [q / ]q        Previous / next quickfix item
  Alt t          Toggle a floating terminal when Vim supports popups + terminal
  Alt h/l        Resize vertical panes
  Alt j/k        Resize horizontal panes
  Ctrl-w h/l     Move between tree and editor panes
  Ctrl-w </>     Resize vertical panes using Vim's native controls
  Ctrl-w +/-     Resize horizontal panes using Vim's native controls
  Enter          Open quickfix result or tree file

Notes:
  Uses Vim, netrw, quickfix, find, grep, and an optional Vim terminal.
  No Neovim, plugins, fzf, ripgrep, package managers, or install steps.
  Grep prunes .git, node_modules, vendor, dist, build, target, coverage,
  .next, .cache, tmp, and similar large generated directories.
EOF
    return
  fi

  if ! command -v vim >/dev/null 2>&1; then
    printf "vvim: vim was not found in PATH.\n" >&2
    return 1
  fi

  local target="${1:-.}"
  local start_path target_abs target_base
  target_base=$(basename "$target")
  start_path=$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)

  if [ -z "$start_path" ]; then
    printf "vvim: path not found: %s\n" "$target" >&2
    return 1
  fi

  if [ -d "$target" ]; then
    target_abs=$(cd "$target" 2>/dev/null && pwd -P)
  else
    target_abs="$start_path/$target_base"
  fi

  local tmpdir vimrc status target_vim
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/vvim.XXXXXX") || return 1
  vimrc="$tmpdir/vimrc"

  target_vim=${target_abs//\\/\\\\}
  target_vim=${target_vim//\"/\\\"}
  printf "let g:vvim_cli_target = \"%s\"\n" "$target_vim" > "$vimrc"

  cat >> "$vimrc" <<'EOF'
set nocompatible
set hidden
set number
set relativenumber
set splitright
set splitbelow
set wildmenu
set wildmode=longest:full,full
set shortmess+=c
set updatetime=300
set timeout timeoutlen=500 ttimeoutlen=40
set path+=**
set grepformat=%f:%l:%m,%f:%l:%c:%m
set grepprg=grep\ -nIH

let mapleader = " "

let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_altv = 1
let g:netrw_browse_split = 4
let g:netrw_winsize = 28
let g:netrw_keepdir = 0

let g:vvim_prune_dirs = [
      \ '.git',
      \ '.hg',
      \ '.svn',
      \ 'node_modules',
      \ 'vendor',
      \ 'dist',
      \ 'build',
      \ 'target',
      \ 'coverage',
      \ '.next',
      \ '.nuxt',
      \ '.cache',
      \ '.parcel-cache',
      \ '__pycache__',
      \ 'tmp',
      \ 'temp'
      \ ]

function! s:ShellCdPrefix() abort
  return 'cd ' . shellescape(getcwd()) . ' && '
endfunction

function! s:FindPruneExpr() abort
  let parts = []
  for dir in g:vvim_prune_dirs
    call add(parts, '-name ' . shellescape(dir))
  endfor
  return '\( -type d \( ' . join(parts, ' -o ') . ' \) -prune \) -o'
endfunction

function! s:InTree() abort
  return &filetype ==# 'netrw' || expand('%:t') ==# 'NetrwTreeListing' || isdirectory(expand('%:p'))
endfunction

function! s:ProjectRoot(path) abort
  if isdirectory(a:path)
    let dir = fnamemodify(a:path, ':p')
    let fallback = dir
  else
    let dir = fnamemodify(a:path, ':p:h')
    let fallback = dir
  endif

  while !empty(dir)
    if isdirectory(dir . '/.git')
      return dir
    endif

    let parent = fnamemodify(dir, ':h')

    if parent ==# dir
      break
    endif

    let dir = parent
  endwhile

  return fallback
endfunction

function! s:OpenTree() abort
  silent! Lexplore
  if &filetype ==# 'netrw'
    wincmd p
  endif
endfunction

function! s:ShowDashboard() abort
  let root = getcwd()

  enew
  file vvim-dashboard
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal modifiable noreadonly
  call setline(1, [
        \ 'vvim',
        \ '',
        \ 'Project: ' . root,
        \ '',
        \ 'Space e    tree',
        \ 'Space f f  find files',
        \ 'Space f w  grep text',
        \ 'Space f r  recent files',
        \ 'Space b    buffers',
        \ 'Space h    help',
        \ 'Alt t      terminal',
        \ '',
        \ 'Quickfix: Enter open, [q previous, ]q next, Space q close',
        \ 'Windows: Ctrl-w h/l move, Ctrl-w </> resize, Alt h/j/k/l resize',
        \ ''
        \ ])
  setlocal nomodified
  setlocal nomodifiable
  normal! gg
endfunction

function! s:QuickfixOpen() abort
  if empty(getqflist())
    cclose
    echo 'No results.'
    return
  endif

  botright copen 12
  wincmd p
endfunction

function! s:FindFiles() abort
  if s:InTree()
    echo 'File finder is disabled while focused in the folder tree.'
    return
  endif

  let query = input('Find file: ')
  redraw

  let cmd = s:ShellCdPrefix()
        \ . 'find . '
        \ . s:FindPruneExpr()
        \ . ' -type f -print'

  let files = systemlist(cmd)

  if v:shell_error > 1
    echo 'find failed.'
    return
  endif

  if !empty(query)
    let needle = tolower(query)
    call filter(files, 'stridx(tolower(v:val), needle) >= 0')
  endif

  call filter(files, 'v:val !=# ""')

  if empty(files)
    call setqflist([], 'r')
    cclose
    echo 'No matching files.'
    return
  endif

  call setqflist(map(files, "{'filename': v:val, 'lnum': 1, 'text': v:val}"), 'r')
  call s:QuickfixOpen()
endfunction

function! s:RecentFiles() abort
  if s:InTree()
    echo 'Recent files are disabled while focused in the folder tree.'
    return
  endif

  let root = fnamemodify(getcwd(), ':p')
  let items = []

  for file in v:oldfiles
    let full = fnamemodify(file, ':p')

    if filereadable(full) && stridx(full, root) == 0
      call add(items, {
            \ 'filename': full,
            \ 'lnum': 1,
            \ 'text': fnamemodify(full, ':.')
            \ })
    endif
  endfor

  if empty(items)
    call setqflist([], 'r')
    cclose
    echo 'No recent files for this project.'
    return
  endif

  call setqflist(items, 'r')
  call s:QuickfixOpen()
endfunction

function! s:Buffers() abort
  if s:InTree()
    echo 'Buffer picker is disabled while focused in the folder tree.'
    return
  endif

  let items = []

  for buf in getbufinfo({'buflisted': 1})
    if empty(buf.name)
      continue
    endif

    call add(items, {
          \ 'filename': buf.name,
          \ 'lnum': buf.lnum > 0 ? buf.lnum : 1,
          \ 'text': fnamemodify(buf.name, ':.')
          \ })
  endfor

  if empty(items)
    call setqflist([], 'r')
    cclose
    echo 'No listed buffers.'
    return
  endif

  call setqflist(items, 'r')
  call s:QuickfixOpen()
endfunction

function! s:GrepWord() abort
  if s:InTree()
    echo 'Grep is disabled while focused in the folder tree.'
    return
  endif

  let default = expand('<cword>')
  let pattern = input('Grep: ', default)
  redraw

  if empty(pattern)
    echo 'No grep pattern.'
    return
  endif

  let cmd = s:ShellCdPrefix()
        \ . 'LC_ALL=C find . '
        \ . s:FindPruneExpr()
        \ . ' -type f -exec grep -nIH -e '
        \ . shellescape(pattern)
        \ . ' {} +'

  let results = systemlist(cmd)

  if v:shell_error > 1
    echo 'grep failed.'
    return
  endif

  call setqflist([], 'r')
  if empty(results)
    cclose
    echo 'No grep matches.'
    return
  endif

  cexpr results
  call s:QuickfixOpen()
endfunction

function! s:ToggleTerm() abort
  if exists('s:term_popup') && s:term_popup > 0
    if exists('*popup_close')
      call popup_close(s:term_popup)
    endif
    let s:term_popup = 0
    return
  endif

  if exists('*term_start') && exists('*popup_create') && exists('*win_execute')
    let shell = empty(&shell) ? '/bin/sh' : &shell
    let termbuf = term_start(shell, {'hidden': v:true, 'term_name': 'vvim-terminal'})
    let width = float2nr(&columns * 0.86)
    let height = float2nr(&lines * 0.72)

    if width < 50
      let width = &columns - 4
    endif

    if height < 12
      let height = &lines - 4
    endif

    let s:term_popup = popup_create(termbuf, {
          \ 'title': ' vvim terminal ',
          \ 'pos': 'center',
          \ 'minwidth': width,
          \ 'minheight': height,
          \ 'border': [],
          \ 'padding': [0, 0, 0, 0]
          \ })
    call win_execute(s:term_popup, 'startinsert')
    return
  endif

  botright 12split
  if exists(':terminal') == 2
    terminal
    startinsert
  else
    echo 'This Vim does not support :terminal.'
  endif
endfunction

function! s:StartVvim() abort
  let target = get(g:, 'vvim_cli_target', getcwd())
  let root = s:ProjectRoot(target)
  execute 'cd' fnameescape(root)

  if isdirectory(target)
    call s:ShowDashboard()
    call s:OpenTree()
    return
  endif

  execute 'edit' fnameescape(target)
  call s:OpenTree()
endfunction

nnoremap <silent> <Leader>e :call <SID>OpenTree()<CR>
nnoremap <silent> <Leader>h :call <SID>ShowDashboard()<CR>
nnoremap <silent> <Leader>b :call <SID>Buffers()<CR>
nnoremap <silent> <Leader>ff :call <SID>FindFiles()<CR>
nnoremap <silent> <Leader>fr :call <SID>RecentFiles()<CR>
nnoremap <silent> <Leader>fw :call <SID>GrepWord()<CR>
nnoremap <silent> <Leader>q :cclose<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> <M-t> :call <SID>ToggleTerm()<CR>
nnoremap <silent> <Esc>t :call <SID>ToggleTerm()<CR>
nnoremap <silent> <M-h> :vertical resize -4<CR>
nnoremap <silent> <M-l> :vertical resize +4<CR>
nnoremap <silent> <M-j> :resize -2<CR>
nnoremap <silent> <M-k> :resize +2<CR>
tnoremap <silent> <M-t> <C-W>:call <SID>ToggleTerm()<CR>
tnoremap <silent> <Esc>t <C-W>:call <SID>ToggleTerm()<CR>

augroup vvim
  autocmd!
  autocmd VimEnter * call <SID>StartVvim()
  autocmd FileType qf nnoremap <buffer> <CR> <CR>
augroup END
EOF

  command vim -Nu "$vimrc" --noplugin
  status=$?

  rm -rf "$tmpdir"
  return "$status"
}

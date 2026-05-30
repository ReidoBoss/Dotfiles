" ~/.vimrc
" Fake NvChad-ish Vim config
" No plugins. No custom hotkeys. Plain Vim only.

set nocompatible
syntax on
filetype plugin indent on

" UI
set number
set norelativenumber
set cursorline
set showcmd
set showmode
set ruler
set laststatus=2
set wildmenu
set wildmode=list:longest,full
set cmdheight=1
set scrolloff=8
set sidescrolloff=8
set background=dark

" Only enable this if your Vim supports it
if has("termguicolors")
  set termguicolors
endif

" Editing
set hidden
set backspace=indent,eol,start
set autoindent
set smartindent
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set shiftround
set nowrap
set linebreak
set breakindent

" Search
set ignorecase
set smartcase
set incsearch
set hlsearch

" Splits
set splitbelow
set splitright

" Completion
set completeopt=menu,menuone,noselect

" Better file search with :find
set path+=**

" Ignore noisy folders
set wildignore+=*/node_modules/*
set wildignore+=*/dist/*
set wildignore+=*/build/*
set wildignore+=*/target/*
set wildignore+=*/.git/*
set wildignore+=*/.next/*
set wildignore+=*/.nuxt/*
set wildignore+=*/coverage/*

" Grep integration
set grepprg=grep\ -RIn\ --exclude-dir=.git\ --exclude-dir=node_modules\ --exclude-dir=dist\ --exclude-dir=build\ --exclude-dir=target

" Netrw file explorer settings
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25

" NvChad-ish statusline
set statusline=
set statusline+=\ %f
set statusline+=%m
set statusline+=%r
set statusline+=%=
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\ [%{&fileformat}]
set statusline+=\ %l:%c
set statusline+=\ %p%%\ 

" Colors
highlight Normal       ctermfg=252 ctermbg=NONE guifg=#d4d4d4 guibg=NONE
highlight CursorLine   ctermbg=236 guibg=#2a2a2a
highlight LineNr       ctermfg=244 guifg=#808080
highlight CursorLineNr ctermfg=15  guifg=#ffffff
highlight StatusLine   ctermfg=15 ctermbg=238 guifg=#ffffff guibg=#444444
highlight StatusLineNC ctermfg=8  ctermbg=236 guifg=#888888 guibg=#303030
highlight Visual       ctermbg=239 guibg=#44475a
highlight Search       ctermfg=0 ctermbg=11 guifg=#000000 guibg=#ffff00
highlight IncSearch    ctermfg=0 ctermbg=10 guifg=#000000 guibg=#00ff00
highlight VertSplit    ctermfg=238 ctermbg=NONE guifg=#444444 guibg=NONE

" Syntax-ish colors
highlight Comment      ctermfg=244 guifg=#808080
highlight Constant     ctermfg=215 guifg=#ffaf5f
highlight String       ctermfg=114 guifg=#98c379
highlight Identifier   ctermfg=117 guifg=#61afef
highlight Function     ctermfg=117 guifg=#61afef
highlight Statement    ctermfg=176 guifg=#c678dd
highlight Keyword      ctermfg=176 guifg=#c678dd
highlight Type         ctermfg=180 guifg=#e5c07b
highlight PreProc      ctermfg=176 guifg=#c678dd
highlight Special      ctermfg=209 guifg=#e06c75

" File type tweaks
autocmd FileType vue,javascript,typescript,typescriptreact,json,html,css,scss setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType scala,java setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4

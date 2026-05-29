" ~/.vimrc

set nocompatible
syntax on
filetype plugin indent on

set number
set relativenumber
set cursorline
set hidden
set wildmenu
set wildmode=list:longest,full
set ignorecase
set smartcase
set incsearch
set hlsearch
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set backspace=indent,eol,start

" Better file search with :find
set path+=**

" Ignore noisy folders
set wildignore+=*/node_modules/*
set wildignore+=*/dist/*
set wildignore+=*/build/*
set wildignore+=*/target/*
set wildignore+=*/.git/*

" Grep integration
set grepprg=grep\ -RIn\ --exclude-dir=.git\ --exclude-dir=node_modules\ --exclude-dir=dist\ --exclude-dir=build\ --exclude-dir=target

" Quickfix navigation
nnoremap ]q :cnext<CR>
nnoremap [q :cprev<CR>
nnoremap <leader>qo :copen<CR>
nnoremap <leader>qc :cclose<CR>

" Fast save/quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Open netrw file explorer
nnoremap <leader>e :Ex<CR>

" Clear search highlight
nnoremap <leader>h :nohlsearch<CR>

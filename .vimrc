"inspiration: https://www.youtube.com/watch?v=n9k9scbTuvQ. ThePrimeagen youtube channel
 

syntax on

set noerrorbells
" set tabstop=4 softtabstop=4 shiftwidth=4  expandtab
" set expandtab
" set smartindent
set nu
" set nowrap
set smartcase
set completeopt-=preview "disable preview window when using ycm
set mouse=a
if !has('nvim')
    set ttymouse=sgr " specific for usage with alacritty
endif

set nocompatible    " allow for non-vi compatible features
syntax on           " enable syntax highlighting
filetype indent on  " turn on filetype detection and indenting
set autoindent      " turn on auto indenting

" If you prefer spaces to tabs, uncomment the following:
"  (To get a real tab with these settings, do CTRL-V TAB)
set expandtab       " replace indents with spaces
set tabstop=4
set shiftwidth=2    " set how many spaces per indent
set smarttab        " use spaces as indents at the beginning of lines

" Other useful commands, uncomment as desired:
set background=dark " switch to color scheme for terminals with a dark background
set ignorecase      " ignore case when searching (turn off by ": set noignorecase")
set incsearch       " enable incremental search
set ruler           " show cursor line at the bottom of the terminal
set showmatch       " show bracket matches
set showmode        " display current mode in the status line

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'jremmen/vim-ripgrep'
Plug 'morhetz/gruvbox'
Plug 'mbbill/undotree'
Plug 'preservim/nerdtree'
Plug 'vim-scripts/ctrlp.vim'
Plug 'ap/vim-css-color'
Plug 'vim-airline/vim-airline'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tmhedberg/matchit'
Plug '~/path/to/chapel/highlight/vim'

call plug#end()

colorscheme gruvbox
set background=dark

let mapleader = " "

vnoremap <C-c> "+y
vnoremap <C-v> "+p
nnoremap <leader>w :set nowrap!<CR>
nnoremap <leader>h :wincmd h<CR>
nnoremap <leader>j :wincmd j<CR>
nnoremap <leader>k :wincmd k<CR>
nnoremap <leader>l :wincmd l<CR>
nnoremap <leader>u :UndotreeShow<CR>
nnoremap <C-n> :q<CR>
nnoremap <leader>n :NERDTreeToggle<CR>
" a common shortcut to escape from insert mode
inoremap jk <Esc>

let g:rg_highlight='true'
"let g:rg_command = 'rg --vimgrep -S'
let g:rg_derive_root='true'

let NERDTreeShowHidden=1

let g:ctrl_map='<c-p>'
let g:ctrlp_show_hidden=1




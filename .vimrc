"inspiration: https://www.youtube.com/watch?v=n9k9scbTuvQ. ThePrimeagen youtube channel

syntax on

set noerrorbells
set tabstop=4 softtabstop=4
" set expandtab
set smartindent
set nu
" set nowrap
set smartcase
set incsearch

call plug#begin('~/.vim/plugged')

Plug 'jremmen/vim-ripgrep'
Plug 'morhetz/gruvbox'
Plug 'Valloric/YouCompleteMe'
Plug 'mbbill/undotree'
Plug 'preservim/nerdtree'

call plug#end()

colorscheme gruvbox
set background=dark

let mapleader = " "

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

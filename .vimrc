"inspiration: https://www.youtube.com/watch?v=n9k9scbTuvQ. ThePrimeagen youtube channel
 

syntax on

set noerrorbells
set tabstop=4 softtabstop=4 shiftwidth=4  expandtab
" set expandtab
set smartindent
set nu
" set nowrap
set smartcase
set incsearch
set completeopt-=preview "disable preview window when using ycm
set mouse=a
if !has('nvim')
    set ttymouse=sgr " specific for usage with alacritty
endif

call plug#begin('~/.vim/plugged')

Plug 'jremmen/vim-ripgrep'
Plug 'morhetz/gruvbox'
Plug 'Valloric/YouCompleteMe'
Plug 'mbbill/undotree'
Plug 'preservim/nerdtree'
Plug 'vim-scripts/ctrlp.vim'
Plug 'ap/vim-css-color'
Plug 'vim-airline/vim-airline'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tmhedberg/matchit'

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




"set runtimepath^=~/.vim runtimepath+=~/.vim/after
"let &packpath = &runtimepath
"source ~/.vimrc

syntax on

set noerrorbells
set tabstop=4 softtabstop=4 shiftwidth=4  expandtab
" set expandtab
set smartindent
set nu
set nowrap
set smartcase 
set incsearch
"set completeopt-=preview "disable preview window when using ycm
set mouse=a

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

call plug#begin('~/.vim/plugged')

" coding
Plug 'jremmen/vim-ripgrep'
"Plug 'Valloric/YouCompleteMe'
Plug 'neoclide/coc.nvim'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'nathanaelkane/vim-indent-guides'
" vim-polyglot

" general
"Plug 'vim-scripts/ctrlp.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' 
Plug 'mbbill/undotree'
Plug 'preservim/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'tmhedberg/matchit'

" colorscheme
Plug 'morhetz/gruvbox'
Plug 'ap/vim-css-color'

call plug#end()

colorscheme gruvbox
set background=dark


let mapleader = " "

nnoremap <leader>nh :noh<CR>
nnoremap <leader>r :set relativenumber!<CR>
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

"a common shortcut to escape from insert mode
inoremap jk <Esc>

"Use <Tab> and <S-Tab> to navigate the completion list:
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" use <Enter> to pick the highlighted option in the popup menu. Source:vim fandom
inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"


" vim-ripgrep
let g:rg_highlight='true'
"let g:rg_command = 'rg --vimgrep -S'
let g:rg_derive_root='true'

let NERDTreeShowHidden=1


" airline
let g:airline_theme='gruvbox'                                                                                                             
let g:airline_powerline_fonts = 1                                                                                                         
let g:airline_section_b = '%{getcwd()}' " in section B of the status line display the CWD                                                 
                                                                                                                                          
"TABLINE:                                                                                                                                 
                                                                                                                                          

let g:airline#extensions#coc#enabled = 1               " enable coc extension
let g:airline#extensions#tabline#enabled = 1           " enable airline tabline                                                           
let g:airline#extensions#tabline#show_close_button = 0 " remove 'X' at the end of the tabline                                            
let g:airline#extensions#tabline#tabs_label = ''       " can put text here like BUFFERS to denote buffers (I clear it so nothing is shown)
let g:airline#extensions#tabline#buffers_label = ''    " can put text here like TABS to denote tabs (I clear it so nothing is shown)      
let g:airline#extensions#tabline#fnamemod = ':t'       " disable file paths in the tab                                                    
let g:airline#extensions#tabline#show_tab_count = 0    " dont show tab numbers on the right                                                           
let g:airline#extensions#tabline#show_buffers = 0      " dont show buffers in the tabline                                                 
let g:airline#extensions#tabline#tab_min_count = 2     " minimum of 2 tabs needed to display the tabline                                  
let g:airline#extensions#tabline#show_splits = 0       " disables the buffer name that displays on the right of the tabline               
let g:airline#extensions#tabline#show_tab_nr = 0       " disable tab numbers                                                              
let g:airline#extensions#tabline#show_tab_type = 0     " disables the weird ornage arrow on the tabline

" ctrl-p pluging 
"let g:ctrl_map='<c-p>'
"let g:ctrlp_show_hidden=1

" coc setting
autocmd FileType json syntax match Comment +\/\/.\+$+ "get correct comment highlighting for jsonc

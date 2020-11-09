call plug#begin('~/.vim/plugged')

" coding
Plug 'jremmen/vim-ripgrep'
"Plug 'Valloric/YouCompleteMe'
Plug 'neoclide/coc.nvim'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'nathanaelkane/vim-indent-guides'
" vim-polyglot
Plug 'tpope/vim-commentary'
"Plug 'puremourning/vimspector'
Plug 'justinmk/vim-sneak'

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

set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

Plugin 'vim-airline/vim-airline'

Plugin 'scrooloose/nerdtree'
map <C-n> :NERDTreeToggle<CR>

Plugin 'junegunn/goyo.vim'

Plugin 'vimwiki/vimwiki'
let g:vimwiki_list = [{'path': '~/Dropbox/vimwiki/','syntax': 'markdown', 'ext': '.md'}]

" Plugin 'lervag/vimtex'

Plugin 'xuhdev/vim-latex-live-preview'
let g:livepreview_previewer = 'zathura'
" prevent recompilation automatically
let g:livepreview_cursorhold_recompile = 0

Plugin 'suan/vim-instant-markdown'
let g:instant_markdown_autostart = 0 "disable auto-start
map <leader>md :InstantMarkdownPreview<CR>
let g:instant_markdown_browser = "surf"


"Plugin 'jamshedvesuna/vim-markdown-preview'
"let vim_markdown_preview_browser='surf'
"let vim_markdown_preview_hotkey='<C-m>'
"let vim_markdown_preview_github=1

Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'

Plugin 'ap/vim-css-color'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

set relativenumber

set tabstop=4

"syntax on

syntax enable

highlight Normal ctermbg=Black
highlight Normal ctermfg=LightMagenta

set mouse=a

set spell spelllang=el,en_us

" change the highlight of misspelled words
hi clear SpellBad
hi SpellBad cterm=underline
hi SpellLocal cterm=underline ctermbg=NONE

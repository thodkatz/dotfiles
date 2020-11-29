"set runtimepath^=~/.vim runtimepath+=~/.vim/after
"let &packpath = &runtimepath
"source ~/.vimrc

" general settings
source ~/.config/nvim/general/settings.vim

" vim keys bindings
source ~/.config/nvim/keys/bindings.vim

" load plugins
source ~/.config/nvim/vim-plug/plugs.vim

" config for plugins
source ~/.config/nvim/plug-conf/airline.vim
source ~/.config/nvim/plug-conf/ripgrep.vim
source ~/.config/nvim/plug-conf/coc.vim
source ~/.config/nvim/plug-conf/gruvbox.vim
source ~/.config/nvim/plug-conf/nerdtree.vim
source ~/.config/nvim/plug-conf/undotree.vim
source ~/.config/nvim/plug-conf/fzf.vim
source ~/.config/nvim/plug-conf/vimtex.vim

# If you come from bash you might have to change your $PATH.  export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH=$PATH:~/.emacs.d/bin
export EDITOR=nvim
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH


# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="spaceship"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=5

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# Set fzf installation directory path
# export FZF_BASE=/path/to/fzf/install/dir

# Uncomment to set the FZF_DEFAULT_COMMAND
# export FZF_DEFAULT_COMMAND='<your fzf default commmand>'

# Uncomment the following line to disable fuzzy completion
# DISABLE_FZF_AUTO_COMPLETION="true"

# Uncomment the following line to disable key bindings (CTRL-T, CTRL-R, ALT-C)
# DISABLE_FZF_KEY_BINDINGS="true"

plugins=(
	git
	docker
	zsh-autosuggestions
	zsh-syntax-highlighting
	fzf
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias vim=nvim
alias emblinit='ssh -vv katzalis@sshint.embl.de'
alias embl='ssh -vv katzalis@kreshuk-gpu1.embl.de'
alias mediahoarder='~/repos/personal/my-scripts/archive_media.sh'
alias zshcfg='vim ~/.zshrc'
alias vimcfg='vim ~/.vimrc'
alias nvimcfg='nvim ~/.config/nvim/init.vim'
alias alacrittycfg='vim ~/.config/alacritty/alacritty.yml'
alias dwmcfg='vim ~/Downloads/software/dwm/config.h'
# fv stand for fzf vim
alias fv='vim $(fzf)' 
alias tlmgr='/usr/share/texmf-dist/scripts/texlive/tlmgr.pl --usermode'
alias myeyes='redshift -l 40.38:22.55 &'
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias runm='~/repos/my-scripts/runm'

export PATH="$PATH:$HOME/.local/bin:/opt/miniforge-pypy3/bin/:/opt/matlab_2021a/bin/:/opt/pycharm-community-2021.3.2/bin/:opt/acc-py/:/opt/acc-eclipse/:$HOME/repos/personal/dotfiles:$HOME/repos/personal/dwmblocks/scripts"

# fix grey UI matlab
# source: https://wiki.archlinux.org/title/MATLAB
export _JAVA_AWT_WM_NONREPARENTING=1

eval "$(jump shell)"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniforge-pypy3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniforge-pypy3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniforge-pypy3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniforge-pypy3/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/opt/miniforge-pypy3/etc/profile.d/mamba.sh" ]; then
    . "/opt/miniforge-pypy3/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

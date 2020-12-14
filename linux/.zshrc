# .zshrc

# # Load all files from .shell/zshrc.d directory
# if [ -d $HOME/.shellrc/zshrc.d ]; then
#   for file in $HOME/.shellrc/zshrc.d/*.zsh; do
#     source $file
#   done
# fi

# # Load all files from .shell/rc.d directory
# if [ -d $HOME/.shellrc/rc.d ]; then
#   for file in $HOME/.shellrc/rc.d/*.sh; do
#     source $file
#   done
# fi



# # If you come from bash you might have to change your $PATH.
# export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH

# # Path to your oh-my-zsh installation.
# export ZSH="$HOME/.oh-my-zsh"
export HISTFILE="$HOME/.zsh_history"


# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

# ZSH_THEME="dracula"


# HIST_STAMPS="yyyy-mm-dd"
# zstyle :omz:plugins:ssh-agent agent-forwarding on
# zstyle :omz:plugins:ssh-agent identities id_rsa
# zstyle :omz:plugins:ssh-agent lifetime 4h


# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_CA.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='code'
# else
#   export EDITOR='vim'
# fi

# export EDITOR='code'

# export AWS_PAGER="more"

# Compilation flags

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="code ~/.zshrc"
# alias ohmyzsh="code ~/.oh-my-zsh"



# if [[ "$HOST" = "AG-LAPTOP" ]] then;
#   export ARCHFLAGS="-arch x86_64"
#   export BROWSER="/mnt/c/Windows/explorer.exe"
#   alias clip="clip.exe"
# fi

source $HOME/.aliases
export ZSH_CACHE_DIR="$HOME/.cache/zsh"

source ~/.zplug/init.zsh

DRACULA_DISPLAY_TIME=0
DRACULA_DISPLAY_CONTEXT=0

zplug 'zplug/zplug', \
  hook-build:'zplug --self-manage'

## Customized af-magic theme for zsh
# [ag-magic.zsh-theme](https://gist.github.com/gillisandrew/c53927f5afcb08c0cae3c64edfc2aef9)
# zplug "gillisandrew/0eb690e293369a837ca5c211c11d43b6", \
#   from:gist, \
#   as:theme

zplug "~/projects/gillisandrew/zsh", \
  from:local, \
  use:'ag.zsh-theme', \
  as:theme

## Relay windows GPG and SSH sockets to WSL distro
# [wsl-agent-relay.plugin.zsh](https://gist.github.com/gillisandrew/c53927f5afcb08c0cae3c64edfc2aef9)
zplug "gillisandrew/c53927f5afcb08c0cae3c64edfc2aef9", \
    from:gist, \
    on:'blackreloaded/wsl2-ssh-pageant', \
    if:"[[ ! -z \"$WSL_DISTRO_NAME\" ]]"
zplug "blackreloaded/wsl2-ssh-pageant", \
    as:command, \
    at:v1.2.0, \
    use:'wsl-agent-bridge.exe', \
    rename-to:'wsl-agent-bridge', \
    hook-build:'make && GOOS=windows go build -o wsl-agent-bridge.exe main.go && chmod +x wsl-agent-bridge.exe', \
    if:"[[ ! -z \"$WSL_DISTRO_NAME\" ]]"


zplug "aws-cloudformation/cloudformation-guard", \
    from:gh-r, \
    as:command, \
    use:'(*linux*)', \
    rename-to:'cfn-guard', \
    hook-build:'tar -xvf $1'

## Reload and recompile .zshrc
# [zsh-reload-src.plugin.zsh](https://gist.github.com/gillisandrew/6ea6a28738dfbf6971151b78e5811812)
zplug "gillisandrew/6ea6a28738dfbf6971151b78e5811812", \
  from:gist

zplug "lukechilds/zsh-nvm"

zplug "lukechilds/zsh-better-npm-completion"

zplug "zdharma/fast-syntax-highlighting", \
  defer:2

zplug "andyrichardson/zsh-node-path"

zplug "hcgraf/zsh-sudo"

export EMOJI_CLI_USE_EMOJI="true"
zplug "b4b4r07/emoji-cli"

zplug "b4b4r07/httpstat", \
  as:command, \
  use:'(*).sh', \
  rename-to:'$1'

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

zplug load


GPG_TTY=$(tty)
export GPG_TTY


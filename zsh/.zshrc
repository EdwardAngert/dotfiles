# Path to your oh-my-zsh installation (if installed)
if [ -d "$HOME/.oh-my-zsh" ]; then
  export ZSH="$HOME/.oh-my-zsh"
  
  # Theme - using Powerlevel10k as default, can be overridden by setting ZSH_THEME before sourcing
  : ${ZSH_THEME:="powerlevel10k/powerlevel10k"}
  
  # Allow for personal plugins to be added before this file is sourced
  if [ -z "$CUSTOM_ZSH_PLUGINS_ADDED" ]; then
    # Base plugins
    plugins=(
      git
      brew
      sudo
      zsh-autosuggestions
      zsh-syntax-highlighting
      history-substring-search
    )
    
    # Optional plugins (only if available)
    if command -v docker &>/dev/null; then
      plugins+=(docker)
    fi
    
    if command -v kubectl &>/dev/null; then
      plugins+=(kubectl)
    fi
    
    if [ -d "$HOME/.nvm" ]; then
      plugins+=(nvm)
    fi
    
    if command -v npm &>/dev/null; then
      plugins+=(npm)
    fi
  fi
  
  # Source oh-my-zsh
  source $ZSH/oh-my-zsh.sh
fi

# -------------- User configuration --------------

# History settings
HISTSIZE=50000
SAVEHIST=10000
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
setopt share_history

# Autocompletion
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Directory navigation
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

# Preferred editor
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
elif command -v vim &>/dev/null; then
  export EDITOR='vim'
else
  export EDITOR='nano'
fi

# Fix for many programs that use VISUAL if set
export VISUAL=$EDITOR

# -------------- Aliases --------------

# Config aliases
alias zshrc="$EDITOR ~/.zshrc"
[ -d "$HOME/.oh-my-zsh" ] && alias ohmyzsh="$EDITOR ~/.oh-my-zsh"

# Editor aliases
if command -v nvim &>/dev/null; then
  alias v="nvim"
  alias vi="nvim"
  alias vim="nvim"
  # Create a symlink just in case
  if [ ! -L "$HOME/.local/bin/vi" ] && [ -d "$HOME/.local/bin" ] && [ -x "$(command -v nvim)" ]; then
    ln -sf "$(command -v nvim)" "$HOME/.local/bin/vi" 2>/dev/null || true
  fi
fi

# Git aliases - only add what's not already in the git plugin
if command -v git &>/dev/null; then
  # Personal git identity - can be customized in ~/.gitconfig.local
  GIT_USER_NAME=${GIT_USER_NAME:-"EdwardAngert"}
  GIT_USER_EMAIL=${GIT_USER_EMAIL:-"17991901+EdwardAngert@users.noreply.github.com"}
  
  # Load local git config if it exists
  if [ -f "$HOME/.gitconfig.local" ]; then
    GIT_USER_NAME=$(git config --file "$HOME/.gitconfig.local" --get user.name 2>/dev/null || echo "$GIT_USER_NAME")
    GIT_USER_EMAIL=$(git config --file "$HOME/.gitconfig.local" --get user.email 2>/dev/null || echo "$GIT_USER_EMAIL")
  fi
  
  # Personal git identity alias
  alias git\'sme="git config --local user.name \"$GIT_USER_NAME\" && git config --local user.email \"$GIT_USER_EMAIL\" && echo \"Git identity set to $GIT_USER_NAME\""
  
  # Compare branch to main/master
  alias gdiff="git diff \$(git rev-parse --abbrev-ref HEAD) \$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  
  # Git file finder
  alias gtree="git ls-tree --full-tree -r HEAD"
  
  # Git merge main 
  alias gmm="git merge \$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  
  # Git ignore file
  alias gi="echo '.DS_Store\n.envrc\n.direnv\n*.log\nnode_modules\n.vscode\n.idea\n*.swp\n*.swo\n*.bak\n*.orig' >> .gitignore"
fi

# General aliases
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Navigation shortcuts
mkcd() { mkdir -p "$@" && cd "$@"; }
cdl() { cd "$@" && ls; }

# Safety features
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quick find/grep
ff() { find . -type f -name "*$1*"; }
ffg() { find . -type f -name "*$1*" | xargs grep -l "$2"; }

# System shortcuts
alias dfs='df -h | grep -v tmp'
alias mem='free -m'
alias update-system='if command -v apt &>/dev/null; then sudo apt update && sudo apt upgrade; elif command -v brew &>/dev/null; then brew update && brew upgrade; fi'

# Development shortcuts
alias serve='python3 -m http.server'
alias json='python3 -m json.tool'

# -------------- Environment Setup --------------

# Support for VS Code Remote and Coder
if [ -n "$VSCODE_INJECTION" ] || [ -n "$CODER_WORKSPACE_ID" ]; then
  # Ensure PATH is set correctly for remote development
  if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
  
  # Check for user-installed Neovim in common locations
  if [ -f "/usr/local/bin/nvim" ] && [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    export PATH="/usr/local/bin:$PATH"
  fi
  
  # Fix for vi/vim to use nvim - create aliases if not already set
  if command -v nvim &>/dev/null; then
    alias vi='nvim'
    alias vim='nvim'
  fi
  
  # Set SHELL environment variable to zsh explicitly for VS Code terminal
  export SHELL=$(which zsh)
fi

# NVM setup (if installed)
if [ -d "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

# Faster NVM usage with lazy loading
function nvm_auto() {
  local DEFAULT_NODE_VERSION=$(command cat "$NVM_DIR/alias/default" 2>/dev/null || echo "lts/*")
  nvm use "$DEFAULT_NODE_VERSION" > /dev/null
}

# Add node-specific commands that trigger nvm
node_commands=("node" "npm" "npx" "yarn" "pnpm")
for cmd in "${node_commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    alias $cmd="nvm_auto && command $cmd"
  fi
done

# VS Code (if installed)
# macOS path
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi
# Linux path
if [ -d "$HOME/.vscode/bin" ]; then
  export PATH="$PATH:$HOME/.vscode/bin"
fi

# Homebrew (if installed) - avoid duplicate PATH entries
# macOS Intel
if [ -d "/usr/local/bin" ] && [ "$(uname)" = "Darwin" ] && [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
  export PATH="/usr/local/bin:$PATH"
fi
# macOS Apple Silicon
if [ -d "/opt/homebrew/bin" ] && [ "$(uname)" = "Darwin" ] && [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi
# Linux Homebrew (Linuxbrew)
if [ -d "/home/linuxbrew/.linuxbrew/bin" ] && [ "$(uname)" = "Linux" ] && [[ ":$PATH:" != *":/home/linuxbrew/.linuxbrew/bin:"* ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

# Golang (if installed)
if command -v go &>/dev/null; then
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOPATH/bin
fi

# Custom key bindings for command history
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^R' history-incremental-search-backward

# Extract function - handles various archive formats (only define if not already defined)
if ! type extract &>/dev/null; then
  extract() {
    if [ -f $1 ] ; then
      case $1 in
        *.tar.bz2)   tar xvjf $1    ;;
        *.tar.gz)    tar xvzf $1    ;;
        *.tar.xz)    tar xvJf $1    ;;
        *.bz2)       bunzip2 $1     ;;
        *.rar)       unrar x $1     ;;
        *.gz)        gunzip $1      ;;
        *.tar)       tar xvf $1     ;;
        *.tbz2)      tar xvjf $1    ;;
        *.tgz)       tar xvzf $1    ;;
        *.zip)       unzip $1       ;;
        *.Z)         uncompress $1  ;;
        *.7z)        7z x $1        ;;
        *)           echo "don't know how to extract '$1'" ;;
      esac
    else
      echo "'$1' is not a valid file"
    fi
  }
fi

# Autocompletion for SSH hosts
h=()
if [[ -r ~/.ssh/config ]]; then
  h=($h ${${${(@M)${(f)"$(cat ~/.ssh/config)"}:#Host *}#Host }:#*[*?]*})
fi
if [[ -r ~/.ssh/known_hosts ]]; then
  h=($h ${${${(f)"$(cat ~/.ssh/known_hosts)"}%%\ *}%%,*}) 
fi
zstyle ':completion:*:ssh:*' hosts $h
zstyle ':completion:*:scp:*' hosts $h

# Load Powerlevel10k configuration if it exists
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load local configuration if it exists
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi
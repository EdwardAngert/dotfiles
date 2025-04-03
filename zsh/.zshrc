# Path to your oh-my-zsh installation (if installed)
if [ -d "$HOME/.oh-my-zsh" ]; then
  export ZSH="$HOME/.oh-my-zsh"
  
  # Theme
  ZSH_THEME="robbyrussell"
  
  # Plugins
  plugins=(
    git
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
  
  # Source oh-my-zsh
  source $ZSH/oh-my-zsh.sh
fi

# -------------- User configuration --------------

# Preferred editor
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
elif command -v vim &>/dev/null; then
  export EDITOR='vim'
else
  export EDITOR='nano'
fi

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

# Git aliases (if git is installed)
if command -v git &>/dev/null; then
  alias g="git"
  alias gc="git commit"
  alias gco="git checkout"
  alias gs="git status"
  alias gp="git push"
  alias gpf="git push --force-with-lease"
  alias gpl="git pull"
  alias gst="git stash"
  alias gsp="git stash pop"
  alias gd="git diff"
fi

# General aliases
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# -------------- Environment Setup --------------

# Support for VS Code Remote and Coder
if [ -n "$VSCODE_INJECTION" ] || [ -n "$CODER_WORKSPACE_ID" ]; then
  # Ensure PATH is set correctly for remote development
  if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
  
  # Check for user-installed Neovim in common locations
  if [ -f "/usr/local/bin/nvim" ]; then
    export PATH="/usr/local/bin:$PATH"
  fi
  
  # Fix for vi/vim to use nvim - create aliases
  alias vi='nvim'
  alias vim='nvim'
  
  # Set SHELL environment variable to zsh explicitly for VS Code terminal
  export SHELL=$(which zsh)
fi

# NVM setup (if installed)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# VS Code (if installed)
# macOS path
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi
# Linux path
if [ -d "$HOME/.vscode/bin" ]; then
  export PATH="$PATH:$HOME/.vscode/bin"
fi

# Homebrew (if installed)
# macOS Intel
if [ -d "/usr/local/bin" ] && [ "$(uname)" = "Darwin" ]; then
  export PATH="/usr/local/bin:$PATH"
fi
# macOS Apple Silicon
if [ -d "/opt/homebrew/bin" ] && [ "$(uname)" = "Darwin" ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi
# Linux Homebrew (Linuxbrew)
if [ -d "/home/linuxbrew/.linuxbrew/bin" ] && [ "$(uname)" = "Linux" ]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

# Golang (if installed)
if command -v go &>/dev/null; then
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOPATH/bin
fi
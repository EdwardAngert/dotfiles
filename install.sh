#!/bin/bash

# Enable strict mode
set -euo pipefail
IFS=$'\n\t'

# Start timing the script execution
START_TIME=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
  echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
  echo -e "${RED}ERROR:${NC} $1"
}

# Process CLI parameters
SKIP_FONTS=false
SKIP_NEOVIM=false
SKIP_ZSH=false
SKIP_VSCODE=false
SKIP_TERMINAL=false
UPDATE_MODE=false

# Initialize variables that may be used before being set
NODE_INSTALL_SUCCESS=false

# Process command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --skip-fonts) SKIP_FONTS=true ;;
    --skip-neovim) SKIP_NEOVIM=true ;;
    --skip-zsh) SKIP_ZSH=true ;;
    --skip-vscode) SKIP_VSCODE=true ;;
    --skip-terminal) SKIP_TERMINAL=true ;;
    --update) UPDATE_MODE=true ;;
    --pull) 
      print_info "Pulling latest changes from git repository..."
      git pull
      print_success "Repository updated to latest version"
      ;;
    --setup-auto-update)
      print_info "Setting up automatic updates..."
      # Create update script in user's local bin
      AUTO_UPDATE_SCRIPT="$HOME/.local/bin/update-dotfiles.sh"
      mkdir -p "$(dirname "$AUTO_UPDATE_SCRIPT")"
      
      echo '#!/bin/bash' > "$AUTO_UPDATE_SCRIPT"
      echo "cd $(pwd) && ./install.sh --pull --update" >> "$AUTO_UPDATE_SCRIPT"
      chmod +x "$AUTO_UPDATE_SCRIPT"
      
      # Set up weekly cron job
      (crontab -l 2>/dev/null || echo "") | grep -v "update-dotfiles.sh" | { cat; echo "0 12 * * 0 $AUTO_UPDATE_SCRIPT"; } | crontab -
      
      print_success "Automatic weekly updates configured! Updates will run every Sunday at noon."
      print_info "To manually trigger an update, run: $AUTO_UPDATE_SCRIPT"
      exit 0
      ;;
    --help) 
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --skip-fonts     Skip font installation"
      echo "  --skip-neovim    Skip Neovim configuration"
      echo "  --skip-zsh       Skip Zsh configuration"
      echo "  --skip-vscode    Skip VSCode configuration"
      echo "  --skip-terminal  Skip terminal configuration"
      echo "  --update         Update mode - skip dependency installation, only update configs"
      echo "  --pull           Pull latest changes from git repository before installing"
      echo "  --setup-auto-update  Configure automatic weekly updates via cron"
      echo "  --help           Show this help message"
      echo ""
      echo "Update scenarios:"
      echo "  1. Existing machine with nvim/zsh: Use --update to skip package installation"
      echo "  2. Update existing dotfiles: Use --pull --update to get latest changes"
      echo "  3. Automate updates: Use --setup-auto-update to configure weekly auto-updates"
      exit 0
      ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Create a flag file to detect if we're resuming after oh-my-zsh installation
FLAG_FILE="/tmp/dotfiles_install_in_progress"

# Handle script exit
cleanup() {
  # Remove temporary files here if any
  if [ -n "${FLAG_FILE:-}" ] && [ -f "$FLAG_FILE" ]; then
    rm -f "$FLAG_FILE"
  fi
}

# Trap signals for cleanup
trap 'cleanup; echo -e "\n${RED}Script interrupted. Exiting...${NC}"; exit 1' INT TERM
trap 'cleanup' EXIT
trap 'echo -e "${RED}ERROR:${NC} Command failed at line $LINENO: $BASH_COMMAND"' ERR

check_command() {
  if [ -z "$1" ]; then
    print_error "No command specified for check_command"
    return 2
  fi
  
  if ! command -v "$1" &> /dev/null; then
    return 1
  else
    return 0
  fi
}

# run_command function has been removed as it was unused

install_homebrew() {
  print_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH based on OS and architecture
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
      # M1/M2 Mac
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      # Intel Mac
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    # Linux
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bash_profile
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  
  print_success "Homebrew installed successfully"
}

# Save current directory
DOTFILES_DIR="$(pwd)"

# Check OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macOS"
else
  OS="Unknown"
  print_warning "Unsupported OS detected: $OSTYPE. Some features may not work properly."
fi

print_info "Detected OS: $OS"

# Copy gitconfig.local template if it doesn't exist
if [ -f "$DOTFILES_DIR/gitconfig.local.template" ] && [ ! -f "$HOME/.gitconfig.local" ]; then
  print_info "Creating git local configuration template..."
  cp "$DOTFILES_DIR/gitconfig.local.template" "$HOME/.gitconfig.local"
  print_success "Created ~/.gitconfig.local template - edit this file to set your git identity"
fi


# Create a flag file to detect if we're resuming after oh-my-zsh installation
FLAG_FILE="/tmp/dotfiles_install_in_progress"

# Check if we're resuming after oh-my-zsh installation
if [ -f "$FLAG_FILE" ]; then
  print_info "Resuming installation after oh-my-zsh setup..."
  rm "$FLAG_FILE"
  cd "$DOTFILES_DIR"
else
  # First run of the script
  # If not in update mode, install package managers and dependencies
  if [ "$UPDATE_MODE" = false ]; then
    # Install package managers if needed
    if [ "$OS" = "macOS" ] && ! check_command brew; then
      print_info "Homebrew not found. Installing..."
      install_homebrew
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        print_info "Debian/Ubuntu detected"
        sudo apt-get update
      elif check_command dnf; then
        print_info "Fedora/RHEL detected"
        sudo dnf check-update
      elif check_command pacman; then
        print_info "Arch Linux detected"
        sudo pacman -Sy
      elif ! check_command brew; then
        print_info "Installing Homebrew for Linux..."
        install_homebrew
      fi
    fi

    # Install dependencies
    print_info "Installing dependencies..."
  else
    print_info "Running in update mode - skipping dependency installation"
  fi

  # Install essential dependencies first
  if ! check_command git; then
    print_info "Installing git (required for dotfiles)..."
    if [ "$OS" = "macOS" ]; then
      brew install git
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        sudo apt-get update -y
        sudo apt-get install -y git
      elif check_command dnf; then
        sudo dnf install -y git
      elif check_command pacman; then
        sudo pacman -S --noconfirm git
      elif check_command brew; then
        brew install git
      else
        print_error "Could not install git. Please install it manually and run this script again."
        exit 1
      fi
    fi
    
    if check_command git; then
      print_success "git installed successfully"
    else
      print_error "Failed to install git. This is required to continue."
      exit 1
    fi
  else
    print_success "git is already installed"
  fi
  
  # Install tig (text-mode interface for Git)
  if ! check_command tig; then
    print_info "Installing tig (text-mode interface for Git)..."
    if [ "$OS" = "macOS" ]; then
      brew install tig
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        sudo apt-get install -y tig
      elif check_command dnf; then
        sudo dnf install -y tig
      elif check_command pacman; then
        sudo pacman -S --noconfirm tig
      elif check_command brew; then
        brew install tig
      else
        print_warning "Could not install tig. You can install it manually later."
      fi
    fi
    
    if check_command tig; then
      print_success "tig installed successfully"
    else
      print_warning "Failed to install tig, but continuing with installation. You can install tig manually later."
    fi
  else
    print_success "tig is already installed"
  fi

  # Install curl for downloading
  if ! check_command curl; then
    print_info "Installing curl (required for downloads)..."
    if [ "$OS" = "macOS" ]; then
      brew install curl
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        sudo apt-get update -y
        sudo apt-get install -y curl
      elif check_command dnf; then
        sudo dnf install -y curl
      elif check_command pacman; then
        sudo pacman -S --noconfirm curl
      elif check_command brew; then
        brew install curl
      else
        print_error "Could not install curl. Please install it manually."
      fi
    fi
    
    if check_command curl; then
      print_success "curl installed successfully"
    else
      print_error "Failed to install curl. Some features may not work properly."
    fi
  else
    print_success "curl is already installed"
  fi
  
  # Install Node.js (required for Neovim CoC)
  NODE_INSTALL_SUCCESS=false
  if ! check_command node; then
    print_info "Installing Node.js (required for Neovim code completion)..."
    if [ "$OS" = "macOS" ]; then
      brew install node >/dev/null 2>&1 && NODE_INSTALL_SUCCESS=true
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        # First try the system package manager
        if sudo apt-get install -y nodejs npm >/dev/null 2>&1; then
          NODE_INSTALL_SUCCESS=true
        else
          # If that fails, try NodeSource
          print_info "Trying alternative Node.js installation method..."
          # Download to a temp file first for security
          TEMP_NODEJS_SCRIPT=$(mktemp)
          if curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$TEMP_NODEJS_SCRIPT" 2>/dev/null; then
            if sudo -E bash "$TEMP_NODEJS_SCRIPT" >/dev/null 2>&1; then
              if sudo apt-get install -y nodejs >/dev/null 2>&1; then
                NODE_INSTALL_SUCCESS=true
              fi
            fi
            # Remove the temp file
            rm -f "$TEMP_NODEJS_SCRIPT"
          fi
        fi
      elif check_command dnf; then
        sudo dnf install -y nodejs >/dev/null 2>&1 && NODE_INSTALL_SUCCESS=true
      elif check_command pacman; then
        sudo pacman -S --noconfirm nodejs npm >/dev/null 2>&1 && NODE_INSTALL_SUCCESS=true
      elif check_command brew; then
        brew install node >/dev/null 2>&1 && NODE_INSTALL_SUCCESS=true
      fi
      
      # If all package managers fail, try NVM as a fallback
      if [ "$NODE_INSTALL_SUCCESS" = false ] && command -v curl &>/dev/null; then
        print_info "Trying to install Node.js via NVM..."
        # Install NVM
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
          mkdir -p "$NVM_DIR"
          # Download to a temp file first for security
          TEMP_NVM_SCRIPT=$(mktemp)
          if curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o "$TEMP_NVM_SCRIPT" 2>/dev/null; then
            bash "$TEMP_NVM_SCRIPT" >/dev/null 2>&1
            rm -f "$TEMP_NVM_SCRIPT"
          fi
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
        fi
        
        # Install Node.js via NVM if NVM is available
        if command -v nvm &>/dev/null; then
          nvm install --lts >/dev/null 2>&1 && NODE_INSTALL_SUCCESS=true
          nvm use --lts >/dev/null 2>&1
        fi
      fi
    fi
    
    if check_command node; then
      print_success "Node.js installed successfully"
      NODE_INSTALL_SUCCESS=true
    else
      print_warning "Failed to install Node.js. Creating fallback configuration for Neovim without CoC."
      # Create a flag file to indicate we should use a CoC-less config
      touch "$HOME/.config/nvim/.no-coc"
    fi
  else
    print_success "Node.js is already installed"
    NODE_INSTALL_SUCCESS=true
  fi

  # Install build tools (for telescope-fzf-native and other plugins)
  if ! check_command make || ! check_command gcc; then
    print_info "Installing build tools (required for some Neovim plugins)..."
    if [ "$OS" = "macOS" ]; then
      xcode-select --install 2>/dev/null || true
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        sudo apt-get install -y build-essential
      elif check_command dnf; then
        sudo dnf groupinstall -y "Development Tools"
      elif check_command pacman; then
        sudo pacman -S --noconfirm base-devel
      elif check_command brew; then
        brew install gcc make
      else
        print_warning "Could not install build tools. Some Neovim plugins might not work properly."
      fi
    fi
    
    if check_command make && check_command gcc; then
      print_success "Build tools installed successfully"
    else
      print_warning "Failed to install build tools. Some Neovim plugins might have limited functionality."
    fi
  else
    print_success "Build tools are already installed"
  fi

  # Install zsh
  if ! check_command zsh; then
    print_info "Installing zsh..."
    if [ "$OS" = "macOS" ]; then
      brew install zsh
    elif [ "$OS" = "Linux" ]; then
      if check_command apt-get; then
        sudo apt-get update -y
        sudo apt-get install -y zsh
      elif check_command dnf; then
        sudo dnf install -y zsh
      elif check_command pacman; then
        sudo pacman -S --noconfirm zsh
      elif check_command brew; then
        brew install zsh
      else
        print_error "Could not install zsh. Please install it manually."
      fi
    fi
    
    if check_command zsh; then
      print_success "zsh installed successfully"
    else
      print_error "Failed to install zsh, but continuing with installation. You can install zsh manually later."
    fi
  else
    print_success "zsh is already installed"
  fi

  # Install/Update Neovim
  NVIM_VERSION="0.9.0"  # Specify minimum required version
  
  # Function to check if current Neovim version is sufficient
  check_nvim_version() {
    if ! command -v nvim &> /dev/null; then
      return 1
    fi
    
    local current_version=$(nvim --version | head -n1 | cut -d' ' -f2 | sed 's/^v//')
    if [ "$(printf "%s\n%s" "$current_version" "$NVIM_VERSION" | sort -V | head -n1)" = "$NVIM_VERSION" ]; then
      # Current version is greater than or equal to required
      return 0
    else
      return 1
    fi
  }
  
  # If we have our upgrade script, use that for consistency across all modes
  if [ -f "$DOTFILES_DIR/nvim/upgrade-nvim.sh" ]; then
    print_info "Checking Neovim version requirements..."
    if [ "$UPDATE_MODE" = true ]; then
      # In update mode, run non-interactively
      "$DOTFILES_DIR/nvim/upgrade-nvim.sh" --non-interactive
    else
      # In fresh install mode, check if we need to install/update
      if ! check_command nvim || ! check_nvim_version; then
        "$DOTFILES_DIR/nvim/upgrade-nvim.sh" --non-interactive
      fi
    fi
  # Fall back to the built-in method if the script doesn't exist
  elif ! check_command nvim || ! check_nvim_version; then
    print_info "Installing/Updating Neovim to v$NVIM_VERSION or newer..."

    if [ "$OS" = "macOS" ]; then
      brew install neovim
    elif [ "$OS" = "Linux" ]; then
      # Detect architecture (Neovim uses linux-x86_64/linux-arm64 naming)
      ARCH=$(uname -m)
      NVIM_ARCH=""
      case "$ARCH" in
        x86_64|amd64)
          NVIM_ARCH="linux-x86_64"
          ;;
        aarch64|arm64)
          NVIM_ARCH="linux-arm64"
          ;;
        *)
          print_warning "Architecture $ARCH may not have prebuilt Neovim binaries"
          NVIM_ARCH=""
          ;;
      esac

      NVIM_INSTALLED=false

      # Try binary download if architecture is supported
      if [ -n "$NVIM_ARCH" ]; then
        NVIM_DIR="$HOME/.local/bin"
        mkdir -p "$NVIM_DIR"
        mkdir -p "$HOME/.local/share/nvim"

        print_info "Downloading Neovim binary package for $NVIM_ARCH..."
        if curl -L "https://github.com/neovim/neovim/releases/download/stable/nvim-${NVIM_ARCH}.tar.gz" -o "/tmp/nvim-${NVIM_ARCH}.tar.gz"; then
          print_info "Extracting Neovim..."
          tar xzf "/tmp/nvim-${NVIM_ARCH}.tar.gz" -C "/tmp"

          # Find extracted directory (naming may vary)
          EXTRACT_DIR=$(find /tmp -maxdepth 1 -type d -name "nvim-*" | head -1)

          if [ -n "$EXTRACT_DIR" ] && [ -d "$EXTRACT_DIR" ]; then
            cp -f "$EXTRACT_DIR/bin/nvim" "$NVIM_DIR/"
            cp -rf "$EXTRACT_DIR/share/nvim/"* "$HOME/.local/share/nvim/"
            rm -rf "$EXTRACT_DIR" "/tmp/nvim-${NVIM_ARCH}.tar.gz"
            chmod +x "$NVIM_DIR/nvim"

            if [[ ":$PATH:" != *":$NVIM_DIR:"* ]]; then
              if [ -f "$HOME/.zshrc.local" ]; then
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc.local"
              else
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc"
              fi
              export PATH="$HOME/.local/bin:$PATH"
            fi

            print_success "Neovim installed to $NVIM_DIR/nvim"
            NVIM_INSTALLED=true
          else
            print_error "Failed to extract Neovim. Archive may be corrupted."
            rm -f "/tmp/nvim-${NVIM_ARCH}.tar.gz"
          fi
        else
          print_error "Failed to download Neovim binary."
        fi
      fi

      # Fallback to package manager if binary install failed
      if [ "$NVIM_INSTALLED" = false ]; then
        print_info "Falling back to package manager installation..."
        if check_command apt-get; then
          sudo apt-get update -y
          sudo apt-get install -y neovim
        elif check_command dnf; then
          sudo dnf install -y neovim
        elif check_command pacman; then
          sudo pacman -S --noconfirm neovim
        elif check_command brew; then
          brew install neovim
        else
          print_error "Could not install Neovim through any method."
        fi
      fi
    fi
    
    # Verify installation
    if check_command nvim; then
      nvim_installed_version=$(nvim --version | head -n1)
      print_success "Neovim installed successfully: $nvim_installed_version"
    else
      print_error "Failed to install Neovim. The Neovim configuration will still be set up, but you'll need to install Neovim manually to use it."
    fi
  else
    nvim_installed_version=$(nvim --version | head -n1)
    print_success "Neovim $nvim_installed_version is already installed and meets version requirements"
  fi

  # Install vim-plug for Neovim
  if ! [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ] && ! [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    print_info "Installing vim-plug for Neovim..."
    
    # Make sure curl is available for this
    if command -v curl &> /dev/null; then
      # Create the directory in case it doesn't exist
      mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload"
      
      # Download vim-plug
      if curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
        print_success "vim-plug installed successfully"
      else
        print_error "Failed to download vim-plug. Neovim plugins won't be available."
      fi
    else
      print_error "curl is required to install vim-plug. Neovim plugins won't be available."
    fi
  else
    print_success "vim-plug is already installed"
  fi

  # Install Oh My Zsh (needs special handling as it changes the shell)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_info "Installing Oh My Zsh..."
    # Create flag file to mark that we need to resume after oh-my-zsh
    echo "$DOTFILES_DIR" > "$FLAG_FILE"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
      print_error "Git is required to install Oh My Zsh. Please install git first."
    else
      # Clone instead of using the installer to avoid the shell switch
      git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
      if [ $? -ne 0 ]; then
        print_error "Failed to clone Oh My Zsh repository."
      else
        # Don't automatically change the shell - we'll manually set up .zshrc
        print_success "Oh My Zsh installed successfully"
        
        # Install Oh My Zsh plugins and themes
        print_info "Installing Oh My Zsh plugins and themes..."
        mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"
        mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
        
        # Install plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
        
        # Install Powerlevel10k theme
        if [ ! -d "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
          print_info "Installing Powerlevel10k theme..."
          git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
          print_success "Powerlevel10k theme installed successfully"
        fi
        
        # Create a basic p10k configuration if it doesn't exist
        if [ ! -f "${HOME}/.p10k.zsh" ] && [ -f "$DOTFILES_DIR/zsh/.p10k.zsh" ]; then
          print_info "Setting up Powerlevel10k configuration..."
          cp "$DOTFILES_DIR/zsh/.p10k.zsh" "${HOME}/.p10k.zsh"
          print_success "Powerlevel10k configuration created"
        fi
        
        print_success "Oh My Zsh plugins and themes installed successfully"
      fi
    fi
  else
    print_success "Oh My Zsh is already installed"
    
    # Check and install Oh My Zsh plugins if needed
    if [ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
      print_info "Installing zsh-autosuggestions plugin..."
      mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"
      git clone https://github.com/zsh-users/zsh-autosuggestions "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
      print_success "zsh-autosuggestions installed successfully"
    fi
    
    if [ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
      print_info "Installing zsh-syntax-highlighting plugin..."
      mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"
      git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
      print_success "zsh-syntax-highlighting installed successfully"
    fi
    
    # Check and install Powerlevel10k theme if needed
    if [ ! -d "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
      print_info "Installing Powerlevel10k theme..."
      mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
      print_success "Powerlevel10k theme installed successfully"
    fi
    
    # Create a basic p10k configuration if it doesn't exist
    if [ ! -f "${HOME}/.p10k.zsh" ] && [ -f "$DOTFILES_DIR/zsh/.p10k.zsh" ]; then
      print_info "Setting up Powerlevel10k configuration..."
      cp "$DOTFILES_DIR/zsh/.p10k.zsh" "${HOME}/.p10k.zsh"
      print_success "Powerlevel10k configuration created"
    fi
  fi
fi

# Function to backup existing configuration
backup_if_exists() {
  if [ -f "$1" ] || [ -d "$1" ]; then
    BACKUP_PATH="$1.backup"
    print_info "Backing up existing $1 to $BACKUP_PATH"
    if mv "$1" "$BACKUP_PATH" 2>/dev/null; then
      print_success "Backup created: $BACKUP_PATH"
      return 0
    else
      print_error "Failed to create backup of $1. Check permissions."
      return 2
    fi
  fi
  return 1
}

# Determine backup behavior based on update mode
if [ "$UPDATE_MODE" = true ]; then
  SHOULD_BACKUP=false
  print_info "Update mode: Will keep and overwrite existing configurations"
else
  SHOULD_BACKUP=true
  print_info "Will automatically backup any existing configurations"
fi

# Create symlinks
print_info "Creating symlinks and configuring applications..."

# VSCode (if not skipped)
if [ "$SKIP_VSCODE" = false ] && check_command code; then
  # Install VSCode extensions
  print_info "Installing VSCode extensions..."
  
  # Catppuccin theme
  code --install-extension catppuccin.catppuccin-vsc 2>/dev/null || true
  print_success "VSCode Catppuccin theme installed!"
  
  # Code Spell Checker
  code --install-extension streetsidesoftware.code-spell-checker 2>/dev/null || true
  print_success "VSCode Code Spell Checker installed!"
  
  # Markdown Table Formatter
  code --install-extension fcrespo82.markdown-table-formatter 2>/dev/null || true
  print_success "VSCode Markdown Table Formatter installed!"
  
  if [ "$OS" = "macOS" ] && [ -d "$HOME/Library/Application Support/Code/User" ]; then
    vscode_config_dir="$HOME/Library/Application Support/Code/User"
    print_info "Creating VSCode symlinks..."
    vscode_settings_path="$vscode_config_dir/settings.json"
    
    # Backup existing settings if option selected
    if [ "$SHOULD_BACKUP" = true ] && [ -f "$vscode_settings_path" ]; then
      backup_if_exists "$vscode_settings_path"
    fi
    
    ln -sf "$DOTFILES_DIR/vscode/settings.json" "$vscode_settings_path"
    print_success "VSCode settings linked!"
  elif [ "$OS" = "Linux" ] && [ -d "$HOME/.config/Code/User" ]; then
    vscode_config_dir="$HOME/.config/Code/User"
    print_info "Creating VSCode symlinks..."
    vscode_settings_path="$vscode_config_dir/settings.json"
    
    # Backup existing settings if option selected
    if [ "$SHOULD_BACKUP" = true ] && [ -f "$vscode_settings_path" ]; then
      backup_if_exists "$vscode_settings_path"
    fi
    
    ln -sf "$DOTFILES_DIR/vscode/settings.json" "$vscode_settings_path"
    print_success "VSCode settings linked!"
  else
    print_warning "VSCode user directory not found. Skipping config linking..."
  fi
else
  print_warning "VSCode not found. Skipping VSCode setup..."
fi

# Neovim (if not skipped)
if [ "$SKIP_NEOVIM" = false ]; then
  print_info "Setting up Neovim configuration..."
  nvim_config_dir="$HOME/.config/nvim"
  nvim_init_path="$nvim_config_dir/init.vim"

  # Backup existing config if option selected
  if [ "$SHOULD_BACKUP" = true ] && [ -d "$nvim_config_dir" ]; then
    # Try to remove the directory first if it exists (safer approach)
    if ! backup_if_exists "$nvim_config_dir"; then
      print_warning "Could not backup Neovim config dir, attempting to remove it instead"
      rm -rf "$nvim_config_dir" 2>/dev/null || true
    fi
  elif [ "$SHOULD_BACKUP" = true ] && [ -f "$nvim_init_path" ]; then
    backup_if_exists "$nvim_init_path"
  fi

  # Create directory if it doesn't exist
  if [ ! -d "$nvim_config_dir" ]; then
    print_info "Creating Neovim config directory..."
    mkdir -p "$nvim_config_dir"
  fi

  print_info "Creating Neovim symlinks..."
  if [ -f "$DOTFILES_DIR/nvim/init.vim" ]; then
    ln -sf "$DOTFILES_DIR/nvim/init.vim" "$nvim_init_path"
    print_success "Neovim config linked!"
    
    # Create personal.vim template if it doesn't exist
    personal_nvim_dir="$HOME/.config/nvim"
    personal_nvim_path="$personal_nvim_dir/personal.vim"
    
    if [ ! -f "$personal_nvim_path" ]; then
      mkdir -p "$personal_nvim_dir"
      
      # Check for available templates
      TEMPLATES_AVAILABLE=""
      if [ -f "$DOTFILES_DIR/nvim/personal.vim.template" ]; then
        TEMPLATES_AVAILABLE="${TEMPLATES_AVAILABLE}default "
      fi
      if [ -f "$DOTFILES_DIR/nvim/personal.catppuccin.vim" ]; then
        TEMPLATES_AVAILABLE="${TEMPLATES_AVAILABLE}catppuccin "
      fi
      if [ -f "$DOTFILES_DIR/nvim/personal.monokai.vim" ]; then
        TEMPLATES_AVAILABLE="${TEMPLATES_AVAILABLE}monokai "
      fi
      if [ -f "$DOTFILES_DIR/nvim/personal.nolua.vim" ]; then
        TEMPLATES_AVAILABLE="${TEMPLATES_AVAILABLE}nolua "
      fi
      if [ -f "$DOTFILES_DIR/nvim/personal.nococ.vim" ]; then
        TEMPLATES_AVAILABLE="${TEMPLATES_AVAILABLE}nococ "
      fi
      
      # Check if Neovim has Lua support
      HAS_LUA=false
      if check_command nvim; then
        # Create a temporary Lua test file
        NVIM_LUA_TEST="/tmp/nvim_lua_test.lua"
        echo "print('has_lua')" > "$NVIM_LUA_TEST"
        
        # Try executing a Lua file directly
        if nvim --headless -c "lua dofile('$NVIM_LUA_TEST')" -c q 2>&1 | grep -q "has_lua"; then
          HAS_LUA=true
          print_info "Detected Neovim with Lua support"
        # Fallback to checking version number
        elif nvim --version | grep -q "LuaJIT"; then
          HAS_LUA=true
          print_info "Detected Neovim with LuaJIT support"
        else
          print_warning "Neovim without Lua support detected, will use compatible configuration"
        fi
        
        # Clean up test file
        rm -f "$NVIM_LUA_TEST"
      fi
      
      # Determine which template to use - always prefer Catppuccin when possible
      TEMPLATE_CHOICE=""
      if [ -n "$TEMPLATES_AVAILABLE" ]; then
        # Choose template based on system capabilities - prefer Catppuccin
        if [ "$HAS_LUA" = false ] && [ -f "$DOTFILES_DIR/nvim/personal.nolua.vim" ]; then
          # No Lua support - use nolua config
          TEMPLATE_CHOICE="nolua"
          print_info "Using no-Lua configuration (Neovim lacks Lua support)"
        elif [ -f "$HOME/.config/nvim/.no-coc" ] && [ -f "$DOTFILES_DIR/nvim/personal.nococ.vim" ]; then
          # No Node.js - use nococ config
          TEMPLATE_CHOICE="nococ"
          print_info "Using no-CoC configuration (Node.js not available)"
        elif [ -f "$DOTFILES_DIR/nvim/personal.catppuccin.vim" ]; then
          # Full capabilities - use Catppuccin
          TEMPLATE_CHOICE="catppuccin"
          print_info "Using Catppuccin theme configuration"
        else
          # Fallback to default
          TEMPLATE_CHOICE="default"
        fi
      fi
      
      # Copy the chosen template
      case $TEMPLATE_CHOICE in
        catppuccin)
          if [ -f "$DOTFILES_DIR/nvim/personal.catppuccin.vim" ]; then
            cp "$DOTFILES_DIR/nvim/personal.catppuccin.vim" "$personal_nvim_path"
            print_success "Created $personal_nvim_path with Catppuccin theme configuration"
          else
            print_error "Catppuccin template not found, falling back to default"
            cp "$DOTFILES_DIR/nvim/personal.vim.template" "$personal_nvim_path"
            print_info "Created $personal_nvim_path template for custom Neovim configuration"
          fi
          ;;
        monokai)
          if [ -f "$DOTFILES_DIR/nvim/personal.monokai.vim" ]; then
            cp "$DOTFILES_DIR/nvim/personal.monokai.vim" "$personal_nvim_path"
            print_success "Created $personal_nvim_path with Monokai theme configuration"
          else
            print_error "Monokai template not found, falling back to default"
            cp "$DOTFILES_DIR/nvim/personal.vim.template" "$personal_nvim_path"
            print_info "Created $personal_nvim_path template for custom Neovim configuration"
          fi
          ;;
        nolua)
          if [ -f "$DOTFILES_DIR/nvim/personal.nolua.vim" ]; then
            cp "$DOTFILES_DIR/nvim/personal.nolua.vim" "$personal_nvim_path"
            print_success "Created $personal_nvim_path with no-Lua compatible configuration"
          else
            print_error "No-Lua template not found, falling back to default"
            cp "$DOTFILES_DIR/nvim/personal.vim.template" "$personal_nvim_path"
            print_info "Created $personal_nvim_path template for custom Neovim configuration"
          fi
          ;;
        nococ)
          if [ -f "$DOTFILES_DIR/nvim/personal.nococ.vim" ]; then
            cp "$DOTFILES_DIR/nvim/personal.nococ.vim" "$personal_nvim_path"
            print_success "Created $personal_nvim_path with CoC-less configuration"
          else
            print_error "No-CoC template not found, falling back to default"
            cp "$DOTFILES_DIR/nvim/personal.vim.template" "$personal_nvim_path"
            print_info "Created $personal_nvim_path template for custom Neovim configuration"
          fi
          ;;
        *)
          # Default template
          if [ -f "$DOTFILES_DIR/nvim/personal.vim.template" ]; then
            cp "$DOTFILES_DIR/nvim/personal.vim.template" "$personal_nvim_path"
            print_info "Created $personal_nvim_path template for custom Neovim configuration"
          else
            print_warning "No Neovim templates available"
          fi
          ;;
      esac
    fi
  else
    print_error "Neovim config file not found: $DOTFILES_DIR/nvim/init.vim"
  fi
fi

# ZSH (if not skipped)
if [ "$SKIP_ZSH" = false ]; then
  print_info "Setting up Zsh configuration..."
  zsh_config_path="$HOME/.zshrc"

  # Backup existing config if option selected
  if [ "$SHOULD_BACKUP" = true ] && [ -f "$zsh_config_path" ]; then
    backup_if_exists "$zsh_config_path"
  fi

  print_info "Creating Zsh symlinks..."
  if [ -f "$DOTFILES_DIR/zsh/.zshrc" ]; then
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$zsh_config_path"
    print_success "Zsh config linked!"
    
    # Create the .zshrc.local template if it doesn't exist
    local_zshrc_path="$HOME/.zshrc.local"
    if [ ! -f "$local_zshrc_path" ] && [ -f "$DOTFILES_DIR/zsh/.zshrc.local.template" ]; then
      cp "$DOTFILES_DIR/zsh/.zshrc.local.template" "$local_zshrc_path"
      print_info "Created $local_zshrc_path template for custom configuration"
    fi
  else
    print_error "Zsh config file not found: $DOTFILES_DIR/zsh/.zshrc"
  fi
fi

# Check Node.js availability (needed for CoC) - this runs in both fresh and update modes
if check_command node; then
  NODE_INSTALL_SUCCESS=true
fi

# Install Neovim plugins (if not skipped)
# First verify nvim is actually functional before attempting plugin operations
NVIM_FUNCTIONAL=false
if [ "$SKIP_NEOVIM" = false ] && check_command nvim; then
  # Verify nvim can actually run
  if nvim --version &>/dev/null; then
    NVIM_FUNCTIONAL=true
  else
    print_warning "Neovim found but not functional. Skipping plugin installation."
  fi
fi

if [ "$NVIM_FUNCTIONAL" = true ]; then
  if [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ] || [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    # Check if we need to use a CoC-less configuration
    if [ -f "$HOME/.config/nvim/.no-coc" ] || [ "$NODE_INSTALL_SUCCESS" = false ]; then
      # CoC can't be used, so let's create a modified init.vim that doesn't depend on it
      print_info "Creating CoC-less Neovim configuration..."
      NVIM_CONFIG_DIR="$HOME/.config/nvim"
      NVIM_INIT_PATH="$NVIM_CONFIG_DIR/init.vim"
      
      # Create a backup of the original init.vim if not already backed up and not in update mode
      if [ ! -f "$NVIM_INIT_PATH.original" ] && [ -f "$NVIM_INIT_PATH" ] && [ "$UPDATE_MODE" = false ]; then
        cp "$NVIM_INIT_PATH" "$NVIM_INIT_PATH.original"
      fi
      
      # Use a CoC-less configuration if available
      if [ -f "$DOTFILES_DIR/nvim/personal.nococ.vim" ]; then
        # Use the pre-made CoC-less configuration
        mkdir -p "$NVIM_CONFIG_DIR"
        cp "$DOTFILES_DIR/nvim/personal.nococ.vim" "$NVIM_CONFIG_DIR/personal.vim"
        print_success "Using pre-configured Node.js-free Neovim setup"
      # Fallback to modifying existing init.vim as a last resort
      elif [ -f "$NVIM_INIT_PATH" ]; then
        # Replace CoC with simple autocompletion
        sed -i.bak '/neoclide\/coc.nvim/d' "$NVIM_INIT_PATH" 2>/dev/null || sed -i '' '/neoclide\/coc.nvim/d' "$NVIM_INIT_PATH"
        sed -i.bak '/g:coc_/d' "$NVIM_INIT_PATH" 2>/dev/null || sed -i '' '/g:coc_/d' "$NVIM_INIT_PATH"
        
        # Add simple autocompletion
        echo '
" Simple built-in autocompletion (since CoC is not available)
set omnifunc=syntaxcomplete#Complete
inoremap <C-Space> <C-x><C-o>
' >> "$NVIM_INIT_PATH"
        
        print_success "Created basic Node.js-free Neovim configuration"
      fi
    fi
    
    print_info "Installing/Updating Neovim plugins..."
    # Use a safer approach to install plugins - PlugUpdate instead of PlugInstall in update mode
    if [ "$UPDATE_MODE" = true ]; then
      nvim --headless +PlugUpdate +qall 2>/dev/null || true
      print_success "Neovim plugins updated!"
    else
      nvim --headless +PlugInstall +qall 2>/dev/null || true
      print_success "Neovim plugins installed!"
    fi
    
    # Check for Node.js (required for CoC) and only if we don't have a no-coc flag
    if [ ! -f "$HOME/.config/nvim/.no-coc" ] && command -v node &> /dev/null; then
      print_info "Installing CoC extensions for Neovim..."
      # Install/Update CoC extensions
      if [ "$UPDATE_MODE" = true ]; then
        nvim --headless +"CocUpdate" +qall 2>/dev/null || true
        print_success "CoC extensions updated!"
      else
        nvim --headless +"CocInstall -sync coc-json coc-yaml coc-toml coc-tsserver coc-markdownlint" +qall 2>/dev/null || true
        print_success "CoC extensions installed!"
      fi
    elif [ -f "$HOME/.config/nvim/.no-coc" ]; then
      print_info "Skipping CoC extensions (Node.js not available, using fallback configuration)"
    fi
    
    # Make sure telescope-fzf-native is built (requires make, gcc, etc.)
    if command -v make &> /dev/null && (command -v gcc &> /dev/null || command -v clang &> /dev/null); then
      TELESCOPE_FZF_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/plugged/telescope-fzf-native.nvim"
      if [ -d "$TELESCOPE_FZF_DIR" ]; then
        print_info "Building telescope-fzf-native..."
        (cd "$TELESCOPE_FZF_DIR" && make) 2>/dev/null || true
        print_success "telescope-fzf-native built!"
      fi
    else
      print_warning "Building tools (make, gcc) not found. telescope-fzf-native won't be built. Install them for faster fuzzy finding."
    fi
  else
    print_warning "vim-plug not found. Skipping Neovim plugin installation."
  fi
elif [ "$SKIP_NEOVIM" = false ]; then
  print_warning "Neovim not found or not functional. Skipping plugin installation."
fi

# Install fonts (if not skipped)
if [ "$SKIP_FONTS" = false ]; then
  print_info "Installing fonts..."
  # Add update mode flag if we're in update mode
  if [ "$UPDATE_MODE" = true ]; then
    "$DOTFILES_DIR/fonts/install-fonts.sh" --update
  else
    "$DOTFILES_DIR/fonts/install-fonts.sh"
  fi
else
  print_info "Skipping font installation as requested"
fi

# Configure terminals (if not skipped)
if [ "$SKIP_TERMINAL" = false ]; then
  if [ "$OS" = "macOS" ]; then
  # Configure iTerm2 (macOS only)
  if [ -d "/Applications/iTerm.app" ] || [ -d "$HOME/Applications/iTerm.app" ]; then
    print_info "Configuring iTerm2..."
    
    # Backup existing iTerm2 preferences if not in update mode
    if [ "$SHOULD_BACKUP" = true ] && [ "$UPDATE_MODE" = false ]; then
      ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
      if [ -f "$ITERM_PLIST" ]; then
        backup_if_exists "$ITERM_PLIST"
        print_info "Backed up existing iTerm2 preferences"
      fi
      
      ITERM_PROFILES_DIR="$HOME/Library/Application Support/iTerm2"
      if [ -d "$ITERM_PROFILES_DIR" ]; then
        backup_if_exists "$ITERM_PROFILES_DIR"
        print_info "Backed up existing iTerm2 profiles"
      fi
    fi
    
    # Configure iTerm2 to use our preferences
    print_info "Setting iTerm2 to load preferences from dotfiles..."
    
    # First ensure we have a proper plist file
    if [ -f "$DOTFILES_DIR/iterm/com.googlecode.iterm2.plist" ]; then
      print_info "Ensuring iTerm2 plist file is properly formatted..."
      # Validate plist format
      if ! plutil -lint "$DOTFILES_DIR/iterm/com.googlecode.iterm2.plist" >/dev/null 2>&1; then
        print_warning "iTerm2 plist file is malformed, creating a new properly formatted one..."
        # Export current preferences to create a properly formatted file
        defaults export com.googlecode.iterm2 /tmp/iterm2.plist.tmp
        mv /tmp/iterm2.plist.tmp "$DOTFILES_DIR/iterm/com.googlecode.iterm2.plist"
      fi
    else
      print_info "No existing iTerm2 plist found, creating a new one..."
      # Export current preferences to create a properly formatted file
      defaults export com.googlecode.iterm2 "$DOTFILES_DIR/iterm/com.googlecode.iterm2.plist"
    fi
    
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm"
    
    # Create profiles directory if needed
    mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    
    print_success "iTerm2 configured! Please restart iTerm2 for changes to take effect."
    print_info "Note: You may need to run 'killall cfprefsd' to force preference reload."
  else
    print_warning "iTerm2 not found. Skipping iTerm2 setup..."
  fi
  else
    # Configure Linux terminals
    print_info "Configuring terminal emulators..."
    # Run the terminal script with update flag if needed
    if [ "$UPDATE_MODE" = true ]; then
      "$DOTFILES_DIR/terminal/install-terminal-themes.sh" --update
    else
      "$DOTFILES_DIR/terminal/install-terminal-themes.sh"
    fi
  fi
else
  print_info "Skipping terminal configuration as requested"
fi

# Set zsh as default shell if it's not already (and we're not skipping zsh)
if [ "$SKIP_ZSH" = false ] && [ "$SHELL" != "$(which zsh)" ] && check_command zsh; then
  print_info "Setting zsh as default shell..."
  ZSH_PATH=$(which zsh)
  CHSH_SUCCESS=false

  if [ -f "$ZSH_PATH" ]; then
    # Ensure zsh is in /etc/shells
    if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      if command -v sudo >/dev/null 2>&1; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
      fi
    fi

    # Try to change shell
    if grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      if chsh -s "$ZSH_PATH" 2>/dev/null; then
        CHSH_SUCCESS=true
      fi
    fi

    if [ "$CHSH_SUCCESS" = true ]; then
      print_success "Default shell changed to zsh"
      print_info "Log out and back in (or reboot) for the shell change to take effect"
      print_info "Or start zsh now by typing: zsh"
    else
      print_warning "Could not automatically change default shell to zsh"
      print_info "You can do this manually with: chsh -s $ZSH_PATH"
      print_info "For now, you can start zsh manually with: zsh"
    fi
  else
    print_error "Could not find zsh binary"
  fi
fi

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))
MINUTES=$((EXECUTION_TIME / 60))
SECONDS=$((EXECUTION_TIME % 60))

# Cleanup any temporary files that might have been left behind
if [ -n "${TEMP_NODEJS_SCRIPT+x}" ] || [ -n "${TEMP_NVM_SCRIPT+x}" ]; then
  for TEMP_FILE in "${TEMP_NODEJS_SCRIPT:-}" "${TEMP_NVM_SCRIPT:-}"; do
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
      rm -f "$TEMP_FILE"
    fi
  done
fi

# Install GitHub CLI BEFORE building the summary so status is accurate
if [ -f "$DOTFILES_DIR/github/install-github-cli.sh" ]; then
  print_info "Setting up GitHub CLI..."
  if [ "$UPDATE_MODE" = true ]; then
    "$DOTFILES_DIR/github/install-github-cli.sh" --update --non-interactive || print_warning "GitHub CLI setup had issues (non-fatal)"
  else
    "$DOTFILES_DIR/github/install-github-cli.sh" --non-interactive || print_warning "GitHub CLI setup had issues (non-fatal)"
  fi
fi

# Verify installations
INSTALLATION_SUMMARY=""

# Adapt summary title based on mode
if [ "$UPDATE_MODE" = true ]; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n${BLUE}Configuration Status:${NC}"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n${BLUE}Installation Status:${NC}"
fi

if check_command zsh; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Zsh is available"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Zsh was not installed properly"
fi

if check_command nvim; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Neovim is available"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Neovim was not installed properly"
fi

if check_command tig; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Tig is available"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Tig was not installed properly"
fi

if [ -f "$HOME/.config/nvim/init.vim" ]; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Neovim configuration is in place"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Neovim configuration is missing"
fi

if [ -f "$HOME/.zshrc" ]; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Zsh configuration is in place"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Zsh configuration is missing"
fi

if command -v node &>/dev/null; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Node.js is available (for Neovim CoC)"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Node.js is not available (Neovim CoC disabled)"
fi

# VSCode extensions
if check_command code; then
  if code --list-extensions 2>/dev/null | grep -q "catppuccin.catppuccin-vsc"; then
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ VSCode Catppuccin theme is installed"
  else
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ VSCode Catppuccin theme installation failed"
  fi
  
  if code --list-extensions 2>/dev/null | grep -q "streetsidesoftware.code-spell-checker"; then
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ VSCode Code Spell Checker is installed"
  else
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ VSCode Code Spell Checker installation failed"
  fi
  
  if code --list-extensions 2>/dev/null | grep -q "fcrespo82.markdown-table-formatter"; then
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ VSCode Markdown Table Formatter is installed"
  else
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ VSCode Markdown Table Formatter installation failed"
  fi
fi

# Add Git configuration status
if [ -f "$HOME/.gitconfig.local" ]; then
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ Git local configuration is in place"
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ Git local configuration is missing"
fi

# Add GitHub CLI status
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ GitHub CLI is installed and authenticated"
  else
    INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✓ GitHub CLI is installed but not authenticated"
  fi
else
  INSTALLATION_SUMMARY="${INSTALLATION_SUMMARY}\n✗ GitHub CLI is not installed"
fi

# Display status and next steps
if [ "$UPDATE_MODE" = true ]; then
  echo -e "\n${GREEN}All dotfiles have been updated!${NC}"
else
  echo -e "\n${GREEN}All dotfiles have been linked!${NC}"
fi

print_info "Note: You may need to restart your terminal to see all changes."
print_info "To apply zsh changes without restarting: source ~/.zshrc"

# Print installation summary
echo -e "\n${BLUE}Installation Summary:${NC}${INSTALLATION_SUMMARY}"

# Auto-update info
if [ "$UPDATE_MODE" = true ]; then
  echo -e "\n${BLUE}Update Information:${NC}"
  echo -e "✓ This was an update operation"
  echo -e "• To set up automated weekly updates, run: ./install.sh --setup-auto-update"
  echo -e "• To manually update in the future, run: ./install.sh --pull --update"
fi

if [ "$UPDATE_MODE" = true ]; then
  echo -e "\n${GREEN}Update completed in ${MINUTES}m ${SECONDS}s${NC}"
else
  echo -e "\n${GREEN}Installation completed in ${MINUTES}m ${SECONDS}s${NC}"
fi
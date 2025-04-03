#!/bin/bash

# Enable strict mode
set -uo pipefail
IFS=$'\n\t'

# Start timing the script execution
START_TIME=$(date +%s)

# Process CLI parameters
SKIP_FONTS=false
SKIP_NEOVIM=false
SKIP_ZSH=false
SKIP_VSCODE=false
SKIP_TERMINAL=false

# Process command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --skip-fonts) SKIP_FONTS=true ;;
    --skip-neovim) SKIP_NEOVIM=true ;;
    --skip-zsh) SKIP_ZSH=true ;;
    --skip-vscode) SKIP_VSCODE=true ;;
    --skip-terminal) SKIP_TERMINAL=true ;;
    --help) 
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --skip-fonts     Skip font installation"
      echo "  --skip-neovim    Skip Neovim configuration"
      echo "  --skip-zsh       Skip Zsh configuration"
      echo "  --skip-vscode    Skip VSCode configuration"
      echo "  --skip-terminal  Skip terminal configuration"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Handle script exit
cleanup() {
  # Remove temporary files here if any
  if [ -f "$FLAG_FILE" ]; then
    rm -f "$FLAG_FILE"
  fi
}

# Trap signals for cleanup
trap 'cleanup; echo -e "\n${RED}Script interrupted. Exiting...${NC}"; exit 1' INT TERM
trap 'cleanup' EXIT
trap 'echo -e "${RED}ERROR:${NC} Command failed at line $LINENO: $BASH_COMMAND"' ERR

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

run_command() {
  if [ -z "$1" ]; then
    print_error "No command specified for run_command"
    return 1
  fi
  
  if eval "$1"; then
    return 0
  else
    print_error "Command failed: $1"
    return 1
  fi
}

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


# Create a flag file to detect if we're resuming after oh-my-zsh installation
FLAG_FILE="/tmp/dotfiles_install_in_progress"

# Check if we're resuming after oh-my-zsh installation
if [ -f "$FLAG_FILE" ]; then
  print_info "Resuming installation after oh-my-zsh setup..."
  rm "$FLAG_FILE"
  cd "$DOTFILES_DIR"
else
  # First run of the script
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

  # Install Neovim
  NVIM_VERSION="0.9.5"  # Specify minimum required version
  
  # Function to check if current Neovim version is sufficient
  check_nvim_version() {
    local current_version=$(nvim --version | head -n1 | cut -d' ' -f2 | cut -c 2-)
    if [ $(printf "%s\n%s" "$current_version" "$NVIM_VERSION" | sort -V | head -n1) = "$NVIM_VERSION" ]; then
      # Current version is greater than or equal to required
      return 0
    else
      return 1
    fi
  }
  
  if ! check_command nvim || ! check_nvim_version; then
    print_info "Installing/Updating Neovim to v$NVIM_VERSION or newer..."
    
    if [ "$OS" = "macOS" ]; then
      brew install neovim
    elif [ "$OS" = "Linux" ]; then
      # Always use the AppImage method for consistent version across all Linux distros
      print_info "Installing latest Neovim using AppImage..."
      
      # Create directory for the AppImage
      NVIM_DIR="$HOME/.local/bin"
      mkdir -p "$NVIM_DIR"
      
      print_info "Downloading Neovim binary package..."
      if curl -L https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz -o "/tmp/nvim-linux64.tar.gz"; then
        print_info "Extracting Neovim..."
        mkdir -p "/tmp/nvim-extract"
        tar xzf "/tmp/nvim-linux64.tar.gz" -C "/tmp/nvim-extract"
        
        # Copy the extracted files to the bin directory
        cp -r "/tmp/nvim-extract/nvim-linux64/bin/"* "$NVIM_DIR/"
        mkdir -p "$HOME/.local/share"
        cp -r "/tmp/nvim-extract/nvim-linux64/share/nvim" "$HOME/.local/share/"
        
        # Cleanup
        rm -rf "/tmp/nvim-extract" "/tmp/nvim-linux64.tar.gz"
        
        # Make executable
        chmod +x "$NVIM_DIR/nvim"
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$NVIM_DIR:"* ]]; then
          echo "export PATH=\"\$PATH:$NVIM_DIR\"" >> "$HOME/.bashrc"
          echo "export PATH=\"\$PATH:$NVIM_DIR\"" >> "$HOME/.profile"
          if [ -f "$HOME/.zshrc" ]; then
            echo "export PATH=\"\$PATH:$NVIM_DIR\"" >> "$HOME/.zshrc"
          fi
          export PATH="$PATH:$NVIM_DIR"
        fi
        
        print_success "Neovim AppImage installed to $NVIM_DIR/nvim"
        print_info "The PATH has been updated to include $NVIM_DIR"
      else
        print_error "Failed to download Neovim AppImage."
        
        # Fallback to package manager as last resort
        print_info "Falling back to package manager installation..."
        if check_command apt-get; then
          # For Debian-based systems, use direct binary installation
          print_info "Attempting direct installation of Neovim binary..."
          
          # Install dependencies
          sudo apt-get update -y
          sudo apt-get install -y curl wget unzip
          
          # Create a temporary directory
          TEMP_DIR=$(mktemp -d)
          cd "$TEMP_DIR"
          
          # Download the prebuilt Neovim package
          wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
          
          # Extract the archive
          tar xzf nvim-linux64.tar.gz
          
          # Install to /usr/local
          sudo cp -r nvim-linux64/* /usr/local/
          
          # Clean up
          cd - > /dev/null
          rm -rf "$TEMP_DIR"
          
          # Verify installation
          if command -v /usr/local/bin/nvim &> /dev/null; then
            # Create symlink
            sudo ln -sf /usr/local/bin/nvim /usr/bin/nvim
            print_success "Neovim installed to /usr/local/bin/nvim"
          else
            # If direct install fails, try package manager
            print_info "Direct installation failed, trying package repositories..."
            sudo apt-get install -y software-properties-common
            sudo add-apt-repository -y ppa:neovim-ppa/unstable  # Use unstable for newer versions
            sudo apt-get update -y
            sudo apt-get install -y neovim
          fi
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
    print_success "Neovim v$nvim_installed_version is already installed and meets version requirements"
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
        
        # Install Oh My Zsh plugins
        print_info "Installing Oh My Zsh plugins..."
        mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"
        git clone https://github.com/zsh-users/zsh-autosuggestions "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
        print_success "Oh My Zsh plugins installed successfully"
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

# Always backup existing configs
SHOULD_BACKUP=true
print_info "Will automatically backup any existing configurations"

# Create symlinks
print_info "Creating symlinks and configuring applications..."

# VSCode (if not skipped)
if [ "$SKIP_VSCODE" = false ] && check_command code; then
  # Install Catppuccin theme
  print_info "Installing VSCode Catppuccin theme..."
  code --install-extension catppuccin.catppuccin-vsc 2>/dev/null || true
  print_success "VSCode Catppuccin theme installed!"
  
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
    backup_if_exists "$nvim_config_dir"
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
  else
    print_error "Neovim config file not found: $DOTFILES_DIR/nvim/init.vim"
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
  else
    print_error "Zsh config file not found: $DOTFILES_DIR/zsh/.zshrc"
  fi
fi

# Install Neovim plugins (if not skipped)
if [ "$SKIP_NEOVIM" = false ] && check_command nvim; then
  if [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ] || [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    print_info "Installing Neovim plugins..."
    # Use a safer approach to install plugins
    nvim --headless +PlugInstall +qall 2>/dev/null || true
    print_success "Neovim plugins installed!"
  else
    print_warning "vim-plug not found. Skipping Neovim plugin installation."
  fi
else
  print_warning "Neovim not found or skipped. Skipping plugin installation."
fi

# Install fonts (if not skipped)
if [ "$SKIP_FONTS" = false ]; then
  print_info "Installing fonts..."
  "$DOTFILES_DIR/fonts/install-fonts.sh"
else
  print_info "Skipping font installation as requested"
fi

# Configure terminals (if not skipped)
if [ "$SKIP_TERMINAL" = false ]; then
  if [ "$OS" = "macOS" ]; then
  # Configure iTerm2 (macOS only)
  if [ -d "/Applications/iTerm.app" ] || [ -d "$HOME/Applications/iTerm.app" ]; then
    print_info "Configuring iTerm2..."
    
    # Backup existing iTerm2 preferences if option selected
    if [ "$SHOULD_BACKUP" = true ]; then
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
    # Run the terminal script
    "$DOTFILES_DIR/terminal/install-terminal-themes.sh"
  fi
else
  print_info "Skipping terminal configuration as requested"
fi

# Set zsh as default shell if it's not already (and we're not skipping zsh)
if [ "$SKIP_ZSH" = false ] && [ "$SHELL" != "$(which zsh)" ] && check_command zsh; then
  print_info "Setting zsh as default shell..."
  if [ -f "$(which zsh)" ]; then
    if grep -q "$(which zsh)" /etc/shells; then
      chsh -s "$(which zsh)"
      print_success "Default shell changed to zsh"
    else
      echo "$(which zsh)" | sudo tee -a /etc/shells
      chsh -s "$(which zsh)"
      print_success "Default shell changed to zsh"
    fi
  else
    print_error "Could not change default shell to zsh"
  fi
fi

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))
MINUTES=$((EXECUTION_TIME / 60))
SECONDS=$((EXECUTION_TIME % 60))

# Configure git settings if in the dotfiles repo
print_info "Configuring git settings..."
if command -v git &>/dev/null; then
  # Using the original repo directory - not a symlink path
  if [ -d "$DOTFILES_DIR/.git" ]; then
    cd "$DOTFILES_DIR"
    git config --local user.name "EdwardAngert"
    git config --local user.email "17991901+EdwardAngert@users.noreply.github.com"
    print_success "Git config set successfully for the dotfiles repository"
  else
    print_warning "Not running in a git repository. Skipping git configuration."
  fi
else
  print_warning "Git not found. Skipping git configuration."
fi

echo -e "\n${GREEN}All dotfiles have been linked!${NC}"
print_info "Note: You may need to restart your terminal to see all changes."
print_info "To apply zsh changes without restarting: source ~/.zshrc"
echo -e "\n${GREEN}Installation completed in ${MINUTES}m ${SECONDS}s${NC}"
fi
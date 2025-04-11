#!/usr/bin/env bash
# Script to install and configure GitHub CLI
# This script handles installation across different platforms and includes
# authentication helpers for a smooth setup experience

set -eo pipefail  # Exit on error, fail on pipe failures

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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

# Default options
AUTH_MODE=true
NON_INTERACTIVE=false
UPDATE_MODE=false

# Parse command line arguments
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --no-auth) AUTH_MODE=false ;;
      --non-interactive) NON_INTERACTIVE=true ;;
      --update) UPDATE_MODE=true ;;
      --help) 
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --no-auth           Skip authentication steps"
        echo "  --non-interactive   Run without prompting (for automated scripts)"
        echo "  --update            Only update if already installed"
        echo "  --help              Show this help message"
        exit 0
        ;;
      *) print_error "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
  done
}

# Process arguments
parse_args "$@"

# Function to install GitHub CLI from standalone binary
install_standalone_binary() {
  local temp_dir
  local arch
  local gh_dir
  local version_tag
  
  # Create a temporary directory
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT
  cd "$temp_dir" || return 1
  
  # Determine architecture
  arch=$(uname -m)
  case "$arch" in
    x86_64)  arch="amd64" ;;
    armv*)   arch="arm" ;;
    aarch64) arch="arm64" ;;
    *)
      print_error "Unsupported architecture: $arch"
      return 1
      ;;
  esac
  
  # Get latest version tag
  print_info "Determining latest GitHub CLI version..."
  if ! version_tag=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | cut -c2-); then
    print_error "Failed to determine latest version"
    return 1
  fi
  
  # Download latest release
  print_info "Downloading GitHub CLI v${version_tag} for $arch..."
  if ! curl -sSL "https://github.com/cli/cli/releases/latest/download/gh_${version_tag}_linux_${arch}.tar.gz" -o "gh.tar.gz"; then
    print_error "Download failed"
    return 1
  fi
  
  # Extract
  print_info "Extracting archive..."
  if ! tar xzf "gh.tar.gz"; then
    print_error "Extraction failed"
    return 1
  fi
  
  gh_dir=$(find . -type d -name "gh_*" | head -n 1)
  if [ -z "$gh_dir" ]; then
    print_error "Extraction failed - could not find gh directory"
    return 1
  fi
  
  # Install to user's bin directory
  print_info "Installing to $HOME/.local/bin..."
  cp "$gh_dir/bin/gh" "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/gh"
  
  # Add to PATH if not already there
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
    update_shell_config_path
  fi
  
  return 0
}

# Update shell configuration to include .local/bin in PATH
update_shell_config_path() {
  local path_export='export PATH="$HOME/.local/bin:$PATH"'
  
  if [ -f "$HOME/.zshrc.local" ] && ! grep -q "$path_export" "$HOME/.zshrc.local"; then
    echo "$path_export" >> "$HOME/.zshrc.local"
    print_info "Updated .zshrc.local with PATH"
  elif [ -f "$HOME/.zshrc" ] && ! grep -q "$path_export" "$HOME/.zshrc"; then
    echo "$path_export" >> "$HOME/.zshrc"
    print_info "Updated .zshrc with PATH"
  elif [ -f "$HOME/.bashrc" ] && ! grep -q "$path_export" "$HOME/.bashrc"; then
    echo "$path_export" >> "$HOME/.bashrc"
    print_info "Updated .bashrc with PATH"
  fi
}

# Check if GitHub CLI is already installed
check_gh_installed() {
  if command -v gh &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Check if GitHub CLI is authenticated
check_gh_auth() {
  if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Install GitHub CLI
install_gh() {
  print_info "Installing GitHub CLI..."
  
  # Detect OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS installation
    if command -v brew &>/dev/null; then
      brew install gh
    else
      print_error "Homebrew is required but not installed. Please install Homebrew first."
      return 1
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux installation
    if command -v apt-get &>/dev/null; then
      # Debian/Ubuntu
      print_info "Detected Debian/Ubuntu system"
      
      # Import GitHub CLI GPG key and add repo
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      
      if [ $? -ne 0 ]; then
        print_warning "Failed to import GPG key with sudo. Trying alternative method..."
        # Create local keyring directory if needed
        mkdir -p "$HOME/.gnupg/keyrings"
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg > "$HOME/.gnupg/keyrings/githubcli-archive-keyring.gpg"
        
        # Add to sources list without sudo
        echo "deb [arch=$(dpkg --print-architecture) signed-by=$HOME/.gnupg/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > "$HOME/.sources.list.d/github-cli.list"
        
        # Try with apt-get if available
        sudo apt-get update
        sudo apt-get install -y gh
      else
        # Continue with standard installation
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y gh
      fi
    elif command -v dnf &>/dev/null; then
      # Fedora/RHEL/CentOS
      print_info "Detected Fedora/RHEL/CentOS system"
      sudo dnf install -y 'dnf-command(config-manager)'
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo dnf install -y gh
    elif command -v pacman &>/dev/null; then
      # Arch Linux
      print_info "Detected Arch Linux system"
      sudo pacman -S --noconfirm github-cli
    elif command -v brew &>/dev/null; then
      # Linux Homebrew
      print_info "Using Homebrew on Linux"
      brew install gh
    else
      # Try standalone binary as last resort
      print_info "No package manager detected. Installing standalone binary..."
      
      # Create directory for binaries
      mkdir -p "$HOME/.local/bin"
      
      install_standalone_binary || return 1
    fi
  else
    print_error "Unsupported OS: $OSTYPE"
    return 1
  fi
  
  # Verify installation
  if command -v gh &>/dev/null; then
    print_success "GitHub CLI installed successfully!"
    gh --version
    return 0
  else
    print_error "GitHub CLI installation failed."
    return 1
  fi
}

# Update GitHub CLI
update_gh() {
  print_info "Updating GitHub CLI..."
  
  # Detect OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS update
    if command -v brew &>/dev/null; then
      brew upgrade gh
    else
      print_error "Homebrew is required but not installed."
      return 1
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux update
    if command -v apt-get &>/dev/null; then
      # Debian/Ubuntu
      sudo apt-get update
      sudo apt-get install --only-upgrade -y gh
    elif command -v dnf &>/dev/null; then
      # Fedora/RHEL/CentOS
      sudo dnf upgrade -y gh
    elif command -v pacman &>/dev/null; then
      # Arch Linux
      sudo pacman -Syu --noconfirm github-cli
    elif command -v brew &>/dev/null; then
      # Linux Homebrew
      brew upgrade gh
    elif [ -f "$HOME/.local/bin/gh" ]; then
      # Manual installation - reinstall
      print_info "Updating manually installed GitHub CLI..."
      install_gh
    else
      print_error "Cannot update GitHub CLI. No supported package manager found."
      return 1
    fi
  else
    print_error "Unsupported OS: $OSTYPE"
    return 1
  fi
  
  # Verify update
  if command -v gh &>/dev/null; then
    print_success "GitHub CLI updated successfully!"
    gh --version
    return 0
  else
    print_error "GitHub CLI update failed."
    return 1
  fi
}

# GitHub CLI authentication
authenticate_gh() {
  if check_gh_auth; then
    print_success "GitHub CLI is already authenticated!"
    gh auth status
    return 0
  fi
  
  print_info "Authenticating GitHub CLI..."
  
  if [ "$NON_INTERACTIVE" = true ]; then
    # Non-interactive authentication with token
    print_info "Non-interactive mode: Checking for GitHub token..."
    
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "$GITHUB_TOKEN" | gh auth login --with-token
      if [ $? -eq 0 ]; then
        print_success "Authenticated with GitHub token"
        return 0
      else
        print_error "Failed to authenticate with GitHub token"
        return 1
      fi
    else
      print_warning "Non-interactive mode requires GITHUB_TOKEN environment variable"
      print_info "GitHub CLI is installed but not authenticated"
      return 1
    fi
  else
    # Interactive authentication
    print_info "Starting interactive GitHub authentication..."
    print_info "You will be prompted to authenticate with GitHub"
    
    if [ -t 0 ]; then
      # Terminal is interactive
      gh auth login
      
      if [ $? -eq 0 ]; then
        print_success "Successfully authenticated with GitHub!"
        return 0
      else
        print_error "GitHub authentication failed or was cancelled"
        return 1
      fi
    else
      print_warning "Cannot authenticate in non-interactive mode without token"
      print_info "GitHub CLI is installed but not authenticated"
      return 1
    fi
  fi
}

# Configure GitHub CLI
configure_gh() {
  print_info "Configuring GitHub CLI..."
  
  # Set default git protocol to SSH
  gh config set git_protocol ssh
  
  # Set editor based on preference or availability
  configure_gh_editor
  
  # Set up shell completion
  configure_gh_completion
  
  print_success "GitHub CLI configured successfully!"
}

# Configure GitHub CLI editor
configure_gh_editor() {
  if [ -n "$EDITOR" ]; then
    gh config set editor "$EDITOR"
  elif command -v nvim &>/dev/null; then
    gh config set editor nvim
  elif command -v vim &>/dev/null; then
    gh config set editor vim
  fi
}

# Set up shell completion
configure_gh_completion() {
  local shell_type completion_line
  
  shell_type=$(basename "$SHELL")
  completion_line='eval "$(gh completion -s '"$shell_type"')"'
  
  case "$shell_type" in
    zsh)
      # Check if completion is already configured
      if ! grep -q "gh completion" "$HOME/.zshrc" 2>/dev/null && ! grep -q "gh completion" "$HOME/.zshrc.local" 2>/dev/null; then
        print_info "Adding GitHub CLI completions to Zsh..."
        
        if [ -f "$HOME/.zshrc.local" ]; then
          echo '# GitHub CLI completion' >> "$HOME/.zshrc.local"
          echo "$completion_line" >> "$HOME/.zshrc.local"
        else
          echo '# GitHub CLI completion' >> "$HOME/.zshrc"
          echo "$completion_line" >> "$HOME/.zshrc"
        fi
      fi
      ;;
    bash)
      # Check if completion is already configured
      if ! grep -q "gh completion" "$HOME/.bashrc" 2>/dev/null; then
        print_info "Adding GitHub CLI completions to Bash..."
        echo '# GitHub CLI completion' >> "$HOME/.bashrc"
        echo "$completion_line" >> "$HOME/.bashrc"
      fi
      ;;
    *)
      print_warning "Shell completion not configured for $shell_type"
      ;;
  esac
}

# Main execution
main() {
  if check_gh_installed; then
    handle_existing_installation
  else
    handle_new_installation
  fi
  
  # Configure GitHub CLI (only if installed)
  if check_gh_installed; then
    configure_gh
    print_success "GitHub CLI setup complete!"
  fi
  
  return 0
}

# Handle existing GitHub CLI installation
handle_existing_installation() {
  # If update mode, update
  if [ "$UPDATE_MODE" = true ]; then
    update_gh
  else
    print_success "GitHub CLI is already installed!"
    gh --version
    
    # Authenticate if needed and requested
    if [ "$AUTH_MODE" = true ] && ! check_gh_auth; then
      authenticate_gh
    fi
  fi
}

# Handle new GitHub CLI installation
handle_new_installation() {
  # Skip installation if update mode and not installed
  if [ "$UPDATE_MODE" = true ]; then
    print_info "GitHub CLI not installed. Skipping update."
    return 0
  fi
  
  # Install GitHub CLI
  install_gh || { 
    print_error "Failed to install GitHub CLI. Exiting."
    return 1
  }
  
  # Authenticate if needed and requested
  if [ "$AUTH_MODE" = true ] && ! check_gh_auth; then
    authenticate_gh
  fi
}

# Run main function
main
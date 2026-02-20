#!/usr/bin/env bash
# Script to upgrade Neovim to a specific version in environments where the system package is outdated
# This is especially useful for remote environments like Coder

set -eo pipefail  # Exit on error, fail on pipe failures

# Required minimum Neovim version and target installation version
readonly REQUIRED_VERSION="0.9.0"
readonly INSTALL_VERSION="v0.9.5"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Setup directories upfront to avoid repetition
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly USER_SHARE_DIR="$HOME/.local/share/nvim"
mkdir -p "$USER_BIN_DIR" "$USER_SHARE_DIR"

# Add user bin directory to PATH if not already there
if [[ ":$PATH:" != *":$USER_BIN_DIR:"* ]]; then
  export PATH="$USER_BIN_DIR:$PATH"
fi

# Function to check if Neovim version is sufficient
check_nvim_version() {
  if ! command -v nvim &>/dev/null; then
    echo -e "${YELLOW}Neovim not found.${NC}"
    return 1
  fi
  
  local CURRENT_VERSION=$(nvim --version | head -n1 | cut -d ' ' -f2 | sed 's/^v//')
  
  # Compare versions
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${YELLOW}Neovim $CURRENT_VERSION is older than required version $REQUIRED_VERSION${NC}"
    return 1
  else
    echo -e "${GREEN}Neovim $CURRENT_VERSION meets required version $REQUIRED_VERSION${NC}"
    return 0
  fi
}

# Function to download Neovim with fallback mechanisms
download_neovim() {
  local temp_dir=$1
  local download_url="https://github.com/neovim/neovim/releases/download/$INSTALL_VERSION/nvim-linux64.tar.gz"
  local output_file="$temp_dir/nvim-linux64.tar.gz"
  local dl_success=false

  echo -e "${BLUE}Downloading Neovim $INSTALL_VERSION...${NC}"
  
  # Try wget first if available (more reliable for large files)
  if command -v wget &>/dev/null; then
    wget -q --show-progress "$download_url" -O "$output_file" && dl_success=true
  fi
  
  # If wget failed or isn't available, try curl
  if [ "$dl_success" = false ] && command -v curl &>/dev/null; then
    curl -L --progress-bar -o "$output_file" "$download_url" && dl_success=true
  fi
  
  # Check if download succeeded
  if [ "$dl_success" = false ] || [ ! -s "$output_file" ]; then
    echo -e "${RED}Failed to download Neovim. Check your internet connection.${NC}"
    return 1
  fi
  
  return 0
}

# Function to install latest Neovim
install_latest_neovim() {
  # Create a clean temporary directory for downloads
  local TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT
  
  # Download Neovim
  if ! download_neovim "$TEMP_DIR"; then
    return 1
  fi
  
  # Extract
  echo -e "${BLUE}Extracting Neovim...${NC}"
  tar -xzf "$TEMP_DIR/nvim-linux64.tar.gz" -C "$TEMP_DIR"
  
  # Check if extraction was successful
  if [ ! -d "$TEMP_DIR/nvim-linux64" ]; then
    echo -e "${RED}Failed to extract Neovim. Archive may be corrupted.${NC}"
    return 1
  fi
  
  # Install
  echo -e "${BLUE}Installing Neovim...${NC}"
  cp -f "$TEMP_DIR/nvim-linux64/bin/nvim" "$USER_BIN_DIR/"
  cp -rf "$TEMP_DIR/nvim-linux64/share/nvim/"* "$USER_SHARE_DIR/"
  
  # Make executable
  chmod +x "$USER_BIN_DIR/nvim"
  
  # Update shell configuration files if needed
  update_shell_config
  
  # Verify
  echo -e "${BLUE}Verifying installation...${NC}"
  local NEW_VERSION=$("$USER_BIN_DIR/nvim" --version | head -n1)
  
  if [ -n "$NEW_VERSION" ]; then
    echo -e "${GREEN}$NEW_VERSION installed successfully!${NC}"
    echo -e "${GREEN}Neovim installation complete!${NC}"
    return 0
  else
    echo -e "${RED}Verification failed. Neovim may not have installed correctly.${NC}"
    return 1
  fi
}

# Function to update shell configuration files
update_shell_config() {
  local PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
  local CONFIG_UPDATED=false

  # Try to update .zshrc.local first if it exists
  if [ -f "$HOME/.zshrc.local" ]; then
    if ! grep -q '.local/bin' "$HOME/.zshrc.local" 2>/dev/null; then
      echo "$PATH_EXPORT" >> "$HOME/.zshrc.local"
      CONFIG_UPDATED=true
    fi
  # If no .zshrc.local, try .zshrc
  elif [ -f "$HOME/.zshrc" ]; then
    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
      echo "$PATH_EXPORT" >> "$HOME/.zshrc"
      CONFIG_UPDATED=true
    fi
  # Last resort, update .bashrc
  elif [ -f "$HOME/.bashrc" ]; then
    if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
      echo "$PATH_EXPORT" >> "$HOME/.bashrc"
      CONFIG_UPDATED=true
    fi
  fi

  if [ "$CONFIG_UPDATED" = true ]; then
    echo -e "${BLUE}Updated shell configuration to include $USER_BIN_DIR in PATH${NC}"
  fi
}

# Main entry point
main() {
  # Check if we need to upgrade
  if check_nvim_version; then
    # Already have a sufficient version
    return 0
  fi
  
  # If we got here, we need to upgrade
  if [ "$1" = "--non-interactive" ]; then
    # Non-interactive mode (used by install.sh)
    echo -e "${BLUE}Upgrading Neovim automatically...${NC}"
    install_latest_neovim
  else
    # Interactive mode (when run directly)
    echo -e "${YELLOW}Do you want to install/upgrade Neovim? (y/n)${NC}"
    read -r ANSWER
    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
      install_latest_neovim
    else
      echo -e "${YELLOW}Skipping Neovim upgrade. Some plugins might not work properly.${NC}"
    fi
  fi
}

# Run main function with all arguments passed to the script
main "$@"
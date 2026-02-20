#!/usr/bin/env bash

# Script to install the latest stable Neovim release
# Created for upgrading Neovim in remote environments

set -eo pipefail

# Colors for better readability
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

echo -e "${BLUE}Neovim Installer${NC}"
echo "This script will install the latest stable Neovim to your home directory."

# Check for required dependencies
if ! command -v curl &>/dev/null; then
  echo -e "${RED}Error: curl is required but not installed.${NC}"
  exit 1
fi

# Create directories for installation
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"

# Set up temporary directory with cleanup trap
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
echo -e "${BLUE}Working in temporary directory:${NC} $TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Try to download latest stable Neovim
echo -e "${BLUE}Downloading latest stable Neovim...${NC}"
curl -L -o nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz

# Check if download was successful
if [ ! -f nvim-linux64.tar.gz ] || [ ! -s nvim-linux64.tar.gz ]; then
  echo -e "${YELLOW}Download failed. Trying v0.9.5 specifically...${NC}"
  curl -L -o nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz
fi

# Verify the file was downloaded and has content
if [ ! -f nvim-linux64.tar.gz ] || [ ! -s nvim-linux64.tar.gz ]; then
  echo -e "${RED}Failed to download Neovim. Check your internet connection.${NC}"
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Show file info
echo -e "${BLUE}Downloaded file info:${NC}"
file nvim-linux64.tar.gz
echo ""

# Extract the archive
echo -e "${BLUE}Extracting Neovim...${NC}"
tar xzf nvim-linux64.tar.gz

# Check extraction success
if [ $? -ne 0 ]; then
  echo -e "${RED}Extraction failed. Archive may be corrupted.${NC}"
  echo "Trying alternative extraction method..."
  mkdir -p nvim-linux64
  tar xf nvim-linux64.tar.gz -C nvim-linux64 --strip-components=1
fi

# List extracted contents
echo -e "${BLUE}Extracted content:${NC}"
ls -la
echo ""

# Continue only if extraction succeeded
if [ -d "nvim-linux64" ]; then
  echo -e "${BLUE}Installing Neovim to ${GREEN}$HOME/.local/bin${NC}"
  
  # Copy the executable
  cp -f "$TEMP_DIR/nvim-linux64/bin/nvim" "$HOME/.local/bin/"
  
  # Copy the runtime files
  echo -e "${BLUE}Copying runtime files...${NC}"
  cp -rf "$TEMP_DIR/nvim-linux64/share/nvim" "$HOME/.local/share/"
  
  # Make sure it's executable
  chmod +x "$HOME/.local/bin/nvim"
  
  # Add to PATH if not already there
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"

    # Add to shell config - prefer .zshrc.local if it exists, otherwise .zshrc or .bashrc
    local PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
    if [ -f "$HOME/.zshrc.local" ]; then
      if ! grep -q '.local/bin' "$HOME/.zshrc.local" 2>/dev/null; then
        echo "$PATH_EXPORT" >> "$HOME/.zshrc.local"
        echo -e "${GREEN}Added $HOME/.local/bin to your PATH in .zshrc.local${NC}"
      fi
    elif [ -f "$HOME/.zshrc" ]; then
      if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo "$PATH_EXPORT" >> "$HOME/.zshrc"
        echo -e "${GREEN}Added $HOME/.local/bin to your PATH in .zshrc${NC}"
      fi
    elif [ -f "$HOME/.bashrc" ]; then
      if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo "$PATH_EXPORT" >> "$HOME/.bashrc"
        echo -e "${GREEN}Added $HOME/.local/bin to your PATH in .bashrc${NC}"
      fi
    fi
  fi
  
  # Verify the installation
  echo -e "${BLUE}Verifying installation...${NC}"
  NVIM_VERSION=$("$HOME/.local/bin/nvim" --version | head -n1)
  
  if [ -n "$NVIM_VERSION" ]; then
    echo -e "${GREEN}Success! Neovim installed:${NC} $NVIM_VERSION"
    echo -e "${YELLOW}NOTE:${NC} You may need to restart your shell or run 'source ~/.zshrc' for PATH changes to take effect"
  else
    echo -e "${RED}Installation verification failed.${NC}"
  fi
else
  echo -e "${RED}Extraction failed. Could not find nvim-linux64 directory.${NC}"
  exit 1
fi

# Cleanup is handled by trap
echo -e "${GREEN}Neovim installation complete!${NC}"
echo "Try running: ~/.local/bin/nvim --version"
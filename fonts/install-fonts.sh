#!/bin/bash

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

# Process command line arguments
UPDATE_MODE=false
if [[ "$1" == "--update" ]]; then
  UPDATE_MODE=true
  print_info "Running in update mode - will only install missing fonts"
fi

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
FONT_DIR="$TEMP_DIR/fonts"
JETBRAINS_VERSION="2.304"
JETBRAINS_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v${JETBRAINS_VERSION}/JetBrainsMono-${JETBRAINS_VERSION}.zip"

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macOS"
  FONT_INSTALL_DIR="$HOME/Library/Fonts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="Linux"
  FONT_INSTALL_DIR="$HOME/.local/share/fonts"
else
  OS="Unknown"
  print_warning "Unsupported OS detected: $OSTYPE. Font installation may not work properly."
fi

print_info "Detected OS: $OS"
print_info "Font install directory: $FONT_INSTALL_DIR"

# Create font directory if it doesn't exist
mkdir -p "$FONT_INSTALL_DIR"

# Download and install JetBrains Mono
print_info "Downloading JetBrains Mono..."
mkdir -p "$FONT_DIR"
curl -L "$JETBRAINS_URL" -o "$TEMP_DIR/jetbrains-mono.zip"

if [ $? -ne 0 ]; then
  print_error "Failed to download JetBrains Mono."
  rm -rf "$TEMP_DIR"
  exit 1
fi

print_info "Extracting JetBrains Mono..."
unzip -q "$TEMP_DIR/jetbrains-mono.zip" -d "$FONT_DIR"

if [ $? -ne 0 ]; then
  print_error "Failed to extract JetBrains Mono."
  rm -rf "$TEMP_DIR"
  exit 1
fi

print_info "Installing JetBrains Mono fonts..."

# In update mode, check if fonts already exist
if [ "$UPDATE_MODE" = true ]; then
  # Check for at least one JetBrains Mono font file
  if ls "$FONT_INSTALL_DIR/JetBrainsMono"*.ttf &>/dev/null; then
    print_info "JetBrains Mono fonts already installed, skipping in update mode"
  else
    cp "$FONT_DIR/fonts/ttf/"*.ttf "$FONT_INSTALL_DIR/"
    if [ $? -ne 0 ]; then
      print_error "Failed to install JetBrains Mono fonts."
      rm -rf "$TEMP_DIR"
      exit 1
    fi
  fi
else
  # Install normally in non-update mode
  cp "$FONT_DIR/fonts/ttf/"*.ttf "$FONT_INSTALL_DIR/"
  if [ $? -ne 0 ]; then
    print_error "Failed to install JetBrains Mono fonts."
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

# Refresh font cache on Linux
if [ "$OS" = "Linux" ]; then
  print_info "Refreshing font cache..."
  if command -v fc-cache &> /dev/null; then
    fc-cache -f -v > /dev/null
    print_success "Font cache refreshed."
  else
    print_warning "fc-cache not found. Attempting to install fontconfig..."
    
    # Try to install fontconfig (provides fc-cache)
    if command -v apt-get &> /dev/null; then
      sudo apt-get update -y
      sudo apt-get install -y fontconfig
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y fontconfig
    elif command -v pacman &> /dev/null; then
      sudo pacman -S --noconfirm fontconfig
    else
      print_warning "Could not install fontconfig. Font cache not refreshed."
    fi
    
    # Try again after potential installation
    if command -v fc-cache &> /dev/null; then
      fc-cache -f -v > /dev/null
      print_success "Font cache refreshed."
    else
      print_warning "Font cache not refreshed. You may need to log out and log back in for fonts to be recognized."
    fi
  fi
fi

# Clean up
rm -rf "$TEMP_DIR"

print_success "JetBrains Mono font installed successfully!"
#!/usr/bin/env bash

# Script to install JetBrains Mono font
set -eo pipefail

# Colors
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

# Check for required dependencies
check_dependencies() {
  local missing_deps=()

  if ! command -v curl &>/dev/null; then
    missing_deps+=("curl")
  fi

  if ! command -v unzip &>/dev/null; then
    missing_deps+=("unzip")
  fi

  if [ ${#missing_deps[@]} -gt 0 ]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    print_info "Please install them and run this script again"
    return 1
  fi
  return 0
}

# Process command line arguments
UPDATE_MODE=false
if [[ "$1" == "--update" ]]; then
  UPDATE_MODE=true
  print_info "Running in update mode - will only install missing fonts"
fi

# Check dependencies first
if ! check_dependencies; then
  exit 1
fi

# Create temporary directory for downloads with cleanup trap
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

FONT_DIR="$TEMP_DIR/fonts"
JETBRAINS_VERSION="2.304"
JETBRAINS_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v${JETBRAINS_VERSION}/JetBrainsMono-${JETBRAINS_VERSION}.zip"

# Detect operating system and set font directory
# Always install fonts regardless of OS detection
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macOS"
  FONT_INSTALL_DIR="$HOME/Library/Fonts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="Linux"
  FONT_INSTALL_DIR="$HOME/.local/share/fonts"
else
  # Unknown OS - try to detect best font location
  OS="Unknown"
  print_warning "Unknown OS detected: $OSTYPE"

  # Try common font directories
  if [ -d "$HOME/Library/Fonts" ]; then
    FONT_INSTALL_DIR="$HOME/Library/Fonts"
  elif [ -d "$HOME/.local/share/fonts" ]; then
    FONT_INSTALL_DIR="$HOME/.local/share/fonts"
  elif [ -d "$HOME/.fonts" ]; then
    FONT_INSTALL_DIR="$HOME/.fonts"
  else
    # Default to Linux-style location
    FONT_INSTALL_DIR="$HOME/.local/share/fonts"
  fi
  print_info "Using font directory: $FONT_INSTALL_DIR"
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

# Refresh font cache on Linux/Unix systems
if [ "$OS" = "Linux" ] || [ "$OS" = "Unknown" ]; then
  if command -v fc-cache &>/dev/null; then
    print_info "Refreshing font cache..."
    fc-cache -f > /dev/null 2>&1 && print_success "Font cache refreshed."
  else
    print_info "fc-cache not found - fonts will be available after next login"
  fi
fi

# Cleanup is handled by trap
print_success "JetBrains Mono font installed successfully!"
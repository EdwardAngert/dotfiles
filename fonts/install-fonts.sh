#!/usr/bin/env bash
# fonts/install-fonts.sh - Install JetBrains Mono Nerd Font
#
# This script installs JetBrains Mono Nerd Font which includes icons
# required for Powerlevel10k and other terminal applications.

set -eo pipefail

# ==============================================================================
# Initialization
# ==============================================================================

# Determine script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/network.sh"

# ==============================================================================
# Configuration
# ==============================================================================

# Process command line arguments
UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
  print_info "Running in update mode - will only install missing fonts"
fi

# ==============================================================================
# Dependency Check
# ==============================================================================

check_font_dependencies() {
  local missing_deps=()

  if ! check_command curl && ! check_command wget; then
    missing_deps+=("curl or wget")
  fi

  if ! check_command unzip; then
    missing_deps+=("unzip")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    print_info "Please install them and run this script again"
    return 1
  fi
  return 0
}

# ==============================================================================
# Font Installation
# ==============================================================================

get_font_install_dir() {
  local font_dir=""

  if [[ "$OS" == "macOS" ]]; then
    font_dir="$HOME/Library/Fonts"
  elif [[ "$OS" == "Linux" ]]; then
    font_dir="$HOME/.local/share/fonts"
  else
    # Try common font directories
    if [[ -d "$HOME/Library/Fonts" ]]; then
      font_dir="$HOME/Library/Fonts"
    elif [[ -d "$HOME/.local/share/fonts" ]]; then
      font_dir="$HOME/.local/share/fonts"
    elif [[ -d "$HOME/.fonts" ]]; then
      font_dir="$HOME/.fonts"
    else
      font_dir="$HOME/.local/share/fonts"
    fi
  fi

  echo "$font_dir"
}

install_jetbrains_mono() {
  local font_install_dir
  font_install_dir=$(get_font_install_dir)

  print_info "Detected OS: $OS"
  print_info "Font install directory: $font_install_dir"

  # In update mode, check if fonts already exist
  if [[ "$UPDATE_MODE" == "true" ]]; then
    if ls "$font_install_dir/JetBrainsMonoNerdFont"*.ttf &>/dev/null 2>&1; then
      print_info "JetBrains Mono Nerd Font already installed, skipping in update mode"
      return 0
    fi
  fi

  # Get latest version
  print_info "Fetching latest Nerd Fonts version..."
  local version
  version=$(get_latest_github_release "ryanoasis/nerd-fonts" 2>/dev/null) || true

  if [[ -z "$version" ]]; then
    print_warning "Could not fetch latest version, using fallback v3.3.0"
    version="v3.3.0"
  fi

  local version_number="${version#v}"
  local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/JetBrainsMono.zip"

  print_info "Using JetBrains Mono Nerd Font ${version}"

  # Create temp directory
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT

  # Download font archive
  print_info "Downloading JetBrains Mono Nerd Font..."
  if ! download_with_retry "$download_url" "$temp_dir/jetbrains-mono.zip" "JetBrains Mono"; then
    print_error "Failed to download JetBrains Mono Nerd Font"
    return 1
  fi

  # Extract
  print_info "Extracting JetBrains Mono Nerd Font..."
  if ! unzip -q "$temp_dir/jetbrains-mono.zip" -d "$temp_dir/fonts"; then
    print_error "Failed to extract JetBrains Mono Nerd Font"
    return 1
  fi

  # Create font directory
  safe_mkdir "$font_install_dir"

  # Install fonts
  print_info "Installing JetBrains Mono Nerd Font..."
  if ! cp "$temp_dir/fonts/"*.ttf "$font_install_dir/"; then
    print_error "Failed to install JetBrains Mono Nerd Font"
    return 1
  fi

  # Refresh font cache on Linux
  if [[ "$OS" == "Linux" ]] || [[ "$OS" == "Unknown" ]]; then
    if check_command fc-cache; then
      print_info "Refreshing font cache..."
      fc-cache -f >/dev/null 2>&1 && print_success "Font cache refreshed"
    else
      print_info "fc-cache not found - fonts will be available after next login"
    fi
  fi

  print_success "JetBrains Mono Nerd Font installed successfully!"
  print_info "Set your terminal font to 'JetBrainsMono Nerd Font' (or 'JetBrainsMono NF')"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  if ! check_font_dependencies; then
    exit 1
  fi

  install_jetbrains_mono
}

main "$@"

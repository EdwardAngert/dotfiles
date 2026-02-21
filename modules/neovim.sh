#!/usr/bin/env bash
# modules/neovim.sh - Neovim installation and configuration
#
# Handles Neovim installation:
# - Binary download for Linux (with checksum validation)
# - Homebrew for macOS
# - Package manager fallback
# - vim-plug plugin manager
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/lib/network.sh"
#   source "$DOTFILES_DIR/modules/package-managers.sh"
#   source "$DOTFILES_DIR/modules/neovim.sh"

# Prevent multiple sourcing
[[ -n "${_NEOVIM_SH_LOADED:-}" ]] && return 0
readonly _NEOVIM_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/neovim.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# Minimum required Neovim version
readonly NVIM_MIN_VERSION="${NVIM_MIN_VERSION:-0.9.0}"

# Installation directories
readonly NVIM_USER_BIN="$HOME/.local/bin"
readonly NVIM_USER_SHARE="$HOME/.local/share/nvim"

# ==============================================================================
# Version Checking
# ==============================================================================

# Get current Neovim version
get_nvim_version() {
  if check_command nvim; then
    nvim --version 2>/dev/null | head -n1 | cut -d' ' -f2 | sed 's/^v//'
  else
    echo ""
  fi
}

# Check if Neovim version meets minimum requirement
# Usage: check_nvim_version [minimum_version]
# shellcheck disable=SC2120
check_nvim_version() {
  local min_version="${1:-$NVIM_MIN_VERSION}"
  local current_version

  current_version=$(get_nvim_version)

  if [[ -z "$current_version" ]]; then
    print_debug "Neovim not found"
    return 1
  fi

  if version_compare "$current_version" "$min_version"; then
    print_debug "Neovim $current_version meets minimum $min_version"
    return 0
  else
    print_debug "Neovim $current_version is below minimum $min_version"
    return 1
  fi
}

# Check if Neovim is functional
is_nvim_functional() {
  if ! check_command nvim; then
    return 1
  fi

  # Try to run version check
  nvim --version &>/dev/null
}

# Check if Neovim has Lua support
has_nvim_lua_support() {
  if ! check_command nvim; then
    return 1
  fi

  # Check for LuaJIT in version output
  if nvim --version | grep -q "LuaJIT"; then
    return 0
  fi

  # Try executing Lua code
  local test_file="/tmp/nvim_lua_test_$$.lua"
  echo "print('ok')" > "$test_file"

  if nvim --headless -c "lua dofile('$test_file')" -c q 2>&1 | grep -q "ok"; then
    rm -f "$test_file"
    return 0
  fi

  rm -f "$test_file"
  return 1
}

# ==============================================================================
# Architecture Detection
# ==============================================================================

# Get Neovim archive name for current architecture
get_nvim_archive_name() {
  case "$ARCH" in
    x86_64)
      echo "nvim-linux-x86_64"
      ;;
    arm64)
      echo "nvim-linux-arm64"
      ;;
    arm32)
      print_warning "32-bit ARM is not supported by Neovim prebuilt binaries"
      echo ""
      ;;
    *)
      echo ""
      ;;
  esac
}

# ==============================================================================
# Binary Installation (Linux)
# ==============================================================================

# Download and install Neovim binary
# Usage: install_nvim_binary [version]
install_nvim_binary() {
  local version="${1:-stable}"
  local archive_name
  local download_url
  local temp_dir
  local checksum

  archive_name=$(get_nvim_archive_name)

  if [[ -z "$archive_name" ]]; then
    print_warning "No prebuilt binary available for architecture: $ARCH"
    return 1
  fi

  print_info "Installing Neovim $version binary for $ARCH..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "download and install Neovim $version"
    return 0
  fi

  # Create directories
  mkdir -p "$NVIM_USER_BIN" "$NVIM_USER_SHARE"

  # Create temp directory
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  download_url="https://github.com/neovim/neovim/releases/download/${version}/${archive_name}.tar.gz"

  # Try to get checksum
  checksum=$(get_github_release_sha256 "neovim/neovim" "$version" "${archive_name}.tar.gz" "*.sha256sum" 2>/dev/null) || true

  # Download
  local archive_path="$temp_dir/${archive_name}.tar.gz"

  if [[ -n "$checksum" ]]; then
    print_info "Downloading with checksum verification..."
    if ! download_and_verify "$download_url" "$archive_path" "$checksum" "Neovim"; then
      print_warning "Verified download failed, trying without verification..."
      if ! download_with_retry "$download_url" "$archive_path" "Neovim"; then
        return 1
      fi
    fi
  else
    print_info "Downloading Neovim binary..."
    if ! download_with_retry "$download_url" "$archive_path" "Neovim"; then
      return 1
    fi
  fi

  # Extract
  print_info "Extracting Neovim..."
  if ! tar -xzf "$archive_path" -C "$temp_dir"; then
    print_error "Failed to extract Neovim archive"
    return 1
  fi

  # Find extracted directory (naming may vary)
  local extract_dir
  extract_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "nvim-*" | head -1)

  if [[ -z "$extract_dir" ]] || [[ ! -d "$extract_dir" ]]; then
    print_error "Failed to find extracted Neovim directory"
    return 1
  fi

  # Install
  print_info "Installing Neovim to $NVIM_USER_BIN..."
  cp -f "$extract_dir/bin/nvim" "$NVIM_USER_BIN/"
  chmod +x "$NVIM_USER_BIN/nvim"

  # Copy runtime files
  if [[ -d "$extract_dir/share/nvim" ]]; then
    cp -rf "$extract_dir/share/nvim/"* "$NVIM_USER_SHARE/"
  fi

  # Ensure PATH includes user bin
  add_to_path "$NVIM_USER_BIN"

  # Verify
  if "$NVIM_USER_BIN/nvim" --version &>/dev/null; then
    local installed_version
    installed_version=$("$NVIM_USER_BIN/nvim" --version | head -n1)
    print_success "Neovim installed: $installed_version"
    return 0
  else
    print_error "Neovim installation verification failed"
    return 1
  fi
}

# Add directory to PATH in shell config
add_to_path() {
  local dir="$1"
  local path_export="export PATH=\"$dir:\$PATH\""

  # Check if already in PATH
  if [[ ":$PATH:" == *":$dir:"* ]]; then
    return 0
  fi

  # Add to current session
  export PATH="$dir:$PATH"

  # Add to shell config
  if [[ -f "$HOME/.zshrc.local" ]]; then
    if ! grep -q "$dir" "$HOME/.zshrc.local" 2>/dev/null; then
      echo "$path_export" >> "$HOME/.zshrc.local"
    fi
  elif [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "$dir" "$HOME/.zshrc" 2>/dev/null; then
      echo "$path_export" >> "$HOME/.zshrc"
    fi
  elif [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "$dir" "$HOME/.bashrc" 2>/dev/null; then
      echo "$path_export" >> "$HOME/.bashrc"
    fi
  fi
}

# ==============================================================================
# Package Manager Installation
# ==============================================================================

# Install Neovim via package manager
install_nvim_package_manager() {
  print_info "Installing Neovim via package manager..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Neovim via $PACKAGE_MANAGER"
    return 0
  fi

  case "$PACKAGE_MANAGER" in
    brew)
      brew install neovim
      ;;
    apt)
      sudo apt-get update -y
      sudo apt-get install -y neovim
      ;;
    dnf)
      sudo dnf install -y neovim
      ;;
    pacman)
      sudo pacman -S --noconfirm neovim
      ;;
    apk)
      sudo apk add neovim
      ;;
    *)
      print_error "Unknown package manager: $PACKAGE_MANAGER"
      return 1
      ;;
  esac

  if check_command nvim; then
    print_success "Neovim installed: $(nvim --version | head -n1)"
    return 0
  fi

  return 1
}

# ==============================================================================
# vim-plug Installation
# ==============================================================================

# Install vim-plug plugin manager
install_vim_plug() {
  local plug_path="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"

  if [[ -f "$plug_path" ]] || [[ -f "$HOME/.vim/autoload/plug.vim" ]]; then
    print_success "vim-plug is already installed"
    return 0
  fi

  print_info "Installing vim-plug for Neovim..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install vim-plug"
    return 0
  fi

  if ! check_command curl; then
    print_error "curl is required to install vim-plug"
    return 1
  fi

  # Create directory
  mkdir -p "$(dirname "$plug_path")"

  # Download vim-plug
  if curl -fLo "$plug_path" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
    print_success "vim-plug installed successfully"
    return 0
  else
    print_error "Failed to download vim-plug"
    return 1
  fi
}

# ==============================================================================
# Plugin Installation
# ==============================================================================

# Install Neovim plugins via vim-plug
# Usage: install_nvim_plugins [--update]
install_nvim_plugins() {
  local update_mode="${1:-}"

  if ! is_nvim_functional; then
    print_warning "Neovim not functional, skipping plugin installation"
    return 1
  fi

  local plug_path="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"
  if [[ ! -f "$plug_path" ]] && [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
    print_warning "vim-plug not found, skipping plugin installation"
    return 1
  fi

  print_info "Installing Neovim plugins..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install/update Neovim plugins"
    return 0
  fi

  if [[ "$update_mode" == "--update" ]]; then
    nvim --headless +PlugUpdate +qall 2>/dev/null || true
    print_success "Neovim plugins updated"
  else
    nvim --headless +PlugInstall +qall 2>/dev/null || true
    print_success "Neovim plugins installed"
  fi

  # Build telescope-fzf-native if present
  build_telescope_fzf
}

# Build telescope-fzf-native plugin
build_telescope_fzf() {
  local fzf_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/plugged/telescope-fzf-native.nvim"

  if [[ ! -d "$fzf_dir" ]]; then
    return 0
  fi

  if ! check_command make; then
    print_warning "make not found, cannot build telescope-fzf-native"
    return 1
  fi

  if ! check_command gcc && ! check_command clang; then
    print_warning "No C compiler found, cannot build telescope-fzf-native"
    return 1
  fi

  print_info "Building telescope-fzf-native..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "build telescope-fzf-native"
    return 0
  fi

  (cd "$fzf_dir" && make) 2>/dev/null || true
  print_success "telescope-fzf-native built"
}

# ==============================================================================
# CoC (Conquer of Completion) Setup
# ==============================================================================

# Install CoC extensions
# Usage: install_coc_extensions [--update]
install_coc_extensions() {
  local update_mode="${1:-}"

  # Check if we should skip CoC
  if [[ -f "$HOME/.config/nvim/.no-coc" ]]; then
    print_info "Skipping CoC extensions (Node.js not available)"
    return 0
  fi

  if ! check_command node; then
    print_info "Skipping CoC extensions (Node.js not installed)"
    return 0
  fi

  if ! is_nvim_functional; then
    return 1
  fi

  print_info "Installing CoC extensions..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install CoC extensions"
    return 0
  fi

  if [[ "$update_mode" == "--update" ]]; then
    nvim --headless +"CocUpdate" +qall 2>/dev/null || true
    print_success "CoC extensions updated"
  else
    nvim --headless +"CocInstall -sync coc-json coc-yaml coc-toml coc-tsserver coc-markdownlint" +qall 2>/dev/null || true
    print_success "CoC extensions installed"
  fi
}

# ==============================================================================
# Main Installation Function
# ==============================================================================

# Install Neovim with all components
# Usage: install_neovim [--force] [--skip-plugins]
install_neovim() {
  local force=""
  local skip_plugins=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force="--force" ;;
      --skip-plugins) skip_plugins="--skip-plugins" ;;
      *) ;;
    esac
    shift
  done

  print_section "Installing Neovim"

  # Check if already installed and meets version requirement
  if [[ -z "$force" ]] && check_nvim_version; then
    local version
    version=$(get_nvim_version)
    print_success "Neovim v$version is already installed and meets requirements"
  else
    # Install Neovim
    if [[ "$OS" == "macOS" ]]; then
      install_nvim_package_manager
    elif [[ "$OS" == "Linux" ]]; then
      # Try binary installation first, fall back to package manager
      if ! install_nvim_binary; then
        print_info "Binary installation failed, trying package manager..."
        install_nvim_package_manager
      fi
    else
      install_nvim_package_manager
    fi
  fi

  # Verify installation
  if ! check_command nvim; then
    print_error "Neovim installation failed"
    return 1
  fi

  # Install vim-plug
  install_vim_plug

  # Install plugins (unless skipped)
  if [[ -z "$skip_plugins" ]]; then
    install_nvim_plugins
    install_coc_extensions
  fi

  print_success "Neovim setup complete"
}

# Upgrade Neovim to latest version
# Usage: upgrade_neovim
upgrade_neovim() {
  print_section "Upgrading Neovim"

  local current_version
  current_version=$(get_nvim_version)

  if [[ -n "$current_version" ]]; then
    print_info "Current version: v$current_version"
  fi

  if [[ "$OS" == "Linux" ]]; then
    install_nvim_binary "stable"
  else
    install_nvim_package_manager
  fi

  # Update plugins
  install_nvim_plugins --update
  install_coc_extensions --update
}

#!/usr/bin/env bash
# modules/nodejs.sh - Node.js installation and configuration
#
# Handles Node.js installation via:
# - System package manager
# - NVM (Node Version Manager) as fallback
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/lib/network.sh"
#   source "$DOTFILES_DIR/modules/package-managers.sh"
#   source "$DOTFILES_DIR/modules/nodejs.sh"

# Prevent multiple sourcing
[[ -n "${_NODEJS_SH_LOADED:-}" ]] && return 0
readonly _NODEJS_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/nodejs.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# NVM directory
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Track Node.js installation status
NODE_INSTALL_SUCCESS=false

# ==============================================================================
# Version Checking
# ==============================================================================

# Get current Node.js version
get_node_version() {
  if check_command node; then
    node --version 2>/dev/null | sed 's/^v//'
  else
    echo ""
  fi
}

# Check if Node.js version meets minimum requirement
# Usage: check_node_version [minimum_version]
check_node_version() {
  local min_version="${1:-16.0.0}"
  local current_version

  current_version=$(get_node_version)

  if [[ -z "$current_version" ]]; then
    print_debug "Node.js not found"
    return 1
  fi

  if version_compare "$current_version" "$min_version"; then
    print_debug "Node.js $current_version meets minimum $min_version"
    return 0
  else
    print_debug "Node.js $current_version is below minimum $min_version"
    return 1
  fi
}

# ==============================================================================
# NVM Installation
# ==============================================================================

# Install NVM (Node Version Manager)
install_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    print_success "NVM is already installed"
    return 0
  fi

  print_info "Installing NVM (Node Version Manager)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install NVM"
    return 0
  fi

  # Create NVM directory
  mkdir -p "$NVM_DIR"

  # Download NVM install script to temp file for security
  local temp_script
  temp_script=$(mktemp)

  if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o "$temp_script" 2>/dev/null; then
    print_error "Failed to download NVM installer"
    rm -f "$temp_script"
    return 1
  fi

  # Run installer
  if bash "$temp_script" >/dev/null 2>&1; then
    rm -f "$temp_script"
    print_success "NVM installed successfully"

    # Source NVM
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"

    return 0
  else
    rm -f "$temp_script"
    print_error "NVM installation failed"
    return 1
  fi
}

# Setup NVM in current shell
setup_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    \. "$NVM_DIR/nvm.sh"
    print_debug "NVM loaded"
    return 0
  fi
  return 1
}

# Install Node.js via NVM
# Usage: install_node_via_nvm [version]
# shellcheck disable=SC2120
install_node_via_nvm() {
  local version="${1:-lts/*}"

  # Ensure NVM is available
  if ! setup_nvm; then
    if ! install_nvm; then
      return 1
    fi
    setup_nvm
  fi

  print_info "Installing Node.js via NVM..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "nvm install $version"
    return 0
  fi

  # Check if nvm function is available
  if ! command -v nvm &>/dev/null; then
    print_error "NVM is not available in current shell"
    return 1
  fi

  # Install Node.js
  if nvm install "$version" >/dev/null 2>&1; then
    nvm use "$version" >/dev/null 2>&1
    print_success "Node.js installed via NVM: $(node --version)"
    NODE_INSTALL_SUCCESS=true
    return 0
  else
    print_error "Failed to install Node.js via NVM"
    return 1
  fi
}

# ==============================================================================
# Package Manager Installation
# ==============================================================================

# Install Node.js via system package manager
install_node_via_package_manager() {
  print_info "Installing Node.js via package manager..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Node.js via $PACKAGE_MANAGER"
    return 0
  fi

  local result=1

  case "$PACKAGE_MANAGER" in
    apt)
      # Try system package first
      if sudo apt-get install -y nodejs npm >/dev/null 2>&1; then
        result=0
      else
        # Try NodeSource repository
        print_info "Trying NodeSource repository..."
        local temp_script
        temp_script=$(mktemp)

        if curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$temp_script" 2>/dev/null; then
          if sudo -E bash "$temp_script" >/dev/null 2>&1; then
            if sudo apt-get install -y nodejs >/dev/null 2>&1; then
              result=0
            fi
          fi
          rm -f "$temp_script"
        fi
      fi
      ;;
    dnf)
      sudo dnf install -y nodejs >/dev/null 2>&1 && result=0
      ;;
    pacman)
      sudo pacman -S --noconfirm nodejs npm >/dev/null 2>&1 && result=0
      ;;
    apk)
      sudo apk add nodejs npm >/dev/null 2>&1 && result=0
      ;;
    brew)
      brew install node >/dev/null 2>&1 && result=0
      ;;
    *)
      print_warning "Unknown package manager: $PACKAGE_MANAGER"
      ;;
  esac

  if [[ $result -eq 0 ]] && check_command node; then
    print_success "Node.js installed: $(node --version)"
    NODE_INSTALL_SUCCESS=true
    return 0
  fi

  return 1
}

# ==============================================================================
# Main Installation Function
# ==============================================================================

# Install Node.js using the best available method
# Usage: install_nodejs [--force]
install_nodejs() {
  local force="${1:-}"

  # Check if Node.js is already installed
  if [[ "$force" != "--force" ]] && check_command node; then
    local version
    version=$(get_node_version)
    print_success "Node.js is already installed: v$version"
    NODE_INSTALL_SUCCESS=true
    return 0
  fi

  print_info "Installing Node.js (required for Neovim code completion)..."

  # Try package manager first
  if install_node_via_package_manager; then
    return 0
  fi

  # Fall back to NVM
  print_info "Package manager installation failed, trying NVM..."
  if install_node_via_nvm; then
    return 0
  fi

  # All methods failed
  print_warning "Failed to install Node.js"
  print_info "Creating fallback configuration for Neovim without CoC"

  # Create marker file for CoC-less config
  mkdir -p "$HOME/.config/nvim"
  touch "$HOME/.config/nvim/.no-coc"

  NODE_INSTALL_SUCCESS=false
  return 1
}

# ==============================================================================
# NPM Package Management
# ==============================================================================

# Install a global npm package
# Usage: npm_install_global <package_name>
npm_install_global() {
  local package="$1"

  if ! check_command npm; then
    print_warning "npm not available, cannot install: $package"
    return 1
  fi

  print_info "Installing npm package: $package"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "npm install -g $package"
    return 0
  fi

  npm install -g "$package"
}

# Check if Node.js is functional (can run basic commands)
is_node_functional() {
  if ! check_command node; then
    return 1
  fi

  # Try to execute a simple command
  if node -e "console.log('ok')" &>/dev/null; then
    return 0
  fi

  return 1
}

# ==============================================================================
# Shell Configuration
# ==============================================================================

# Add NVM to shell configuration
configure_nvm_shell() {
  local nvm_config='
# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
'

  # Check if already configured
  if grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null || \
     grep -q 'NVM_DIR' "$HOME/.zshrc.local" 2>/dev/null; then
    print_debug "NVM already configured in shell"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "add NVM configuration to shell"
    return 0
  fi

  # Add to .zshrc.local if it exists, otherwise .zshrc
  if [[ -f "$HOME/.zshrc.local" ]]; then
    echo "$nvm_config" >> "$HOME/.zshrc.local"
    print_info "Added NVM configuration to ~/.zshrc.local"
  elif [[ -f "$HOME/.zshrc" ]]; then
    echo "$nvm_config" >> "$HOME/.zshrc"
    print_info "Added NVM configuration to ~/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    echo "$nvm_config" >> "$HOME/.bashrc"
    print_info "Added NVM configuration to ~/.bashrc"
  fi
}

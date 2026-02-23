#!/usr/bin/env bash
# modules/dependencies.sh - Core dependency installation
#
# Handles installation of essential dependencies:
# - git (version control)
# - curl (downloading)
# - tig (text-mode git interface)
# - build tools (gcc, make for compiling)
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/modules/package-managers.sh"
#   source "$DOTFILES_DIR/modules/dependencies.sh"

# Prevent multiple sourcing
[[ -n "${_DEPENDENCIES_SH_LOADED:-}" ]] && return 0
readonly _DEPENDENCIES_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/dependencies.sh" >&2
  exit 1
fi

if [[ -z "${_PACKAGE_MANAGERS_SH_LOADED:-}" ]]; then
  echo "ERROR: modules/package-managers.sh must be sourced before modules/dependencies.sh" >&2
  exit 1
fi

# ==============================================================================
# Individual Dependency Installation
# ==============================================================================

# Install git
install_git() {
  if check_command git; then
    print_success "git is already installed"
    return 0
  fi

  print_info "Installing git (required for dotfiles)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install git"
    return 0
  fi

  if install_package git; then
    if check_command git; then
      print_success "git installed successfully"
      return 0
    fi
  fi

  print_error "Failed to install git. This is required to continue."
  return 1
}

# Install curl
install_curl() {
  if check_command curl; then
    print_success "curl is already installed"
    return 0
  fi

  print_info "Installing curl (required for downloads)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install curl"
    return 0
  fi

  if install_package curl; then
    if check_command curl; then
      print_success "curl installed successfully"
      return 0
    fi
  fi

  print_error "Failed to install curl. Some features may not work properly."
  return 1
}

# Install wget (useful backup for downloads)
install_wget() {
  if check_command wget; then
    print_success "wget is already installed"
    return 0
  fi

  print_info "Installing wget..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install wget"
    return 0
  fi

  install_package wget || print_warning "wget installation failed (non-critical)"
  return 0
}

# Install tig (text-mode git interface)
install_tig() {
  if check_command tig; then
    print_success "tig is already installed"
    return 0
  fi

  print_info "Installing tig (text-mode interface for Git)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install tig"
    return 0
  fi

  if install_package tig; then
    if check_command tig; then
      print_success "tig installed successfully"
      return 0
    fi
  fi

  print_warning "Failed to install tig (non-critical). You can install it manually later."
  return 0
}

# Install unzip
install_unzip() {
  if check_command unzip; then
    print_success "unzip is already installed"
    return 0
  fi

  print_info "Installing unzip..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install unzip"
    return 0
  fi

  install_package unzip || print_warning "unzip installation failed"
  return 0
}

# Install build tools (gcc, make, etc.)
install_build_tools() {
  local need_build_tools=false

  if ! check_command make; then
    need_build_tools=true
  fi

  if ! check_command gcc && ! check_command clang; then
    need_build_tools=true
  fi

  if [[ "$need_build_tools" == "false" ]]; then
    print_success "Build tools are already installed"
    return 0
  fi

  print_info "Installing build tools (required for some Neovim plugins)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install build tools"
    return 0
  fi

  local result=0

  case "$PACKAGE_MANAGER" in
    apt)
      sudo apt-get install -y build-essential || result=1
      ;;
    dnf)
      sudo dnf groupinstall -y "Development Tools" || result=1
      ;;
    pacman)
      sudo pacman -S --noconfirm base-devel || result=1
      ;;
    apk)
      sudo apk add build-base || result=1
      ;;
    brew)
      if [[ "$OS" == "macOS" ]]; then
        # On macOS, trigger Xcode command line tools installation
        xcode-select --install 2>/dev/null || true
        # Wait a bit for the dialog to appear
        sleep 2
        print_info "Xcode Command Line Tools installation may have been triggered."
        print_info "Please complete the installation if prompted."
      else
        brew install gcc make || result=1
      fi
      ;;
    *)
      print_warning "Could not install build tools - no supported package manager"
      result=1
      ;;
  esac

  if [[ $result -eq 0 ]] && check_command make; then
    print_success "Build tools installed successfully"
    return 0
  else
    print_warning "Build tools installation may have failed. Some Neovim plugins might not work."
    return 1
  fi
}

# ==============================================================================
# Ripgrep (for faster searching)
# ==============================================================================

install_ripgrep() {
  if check_command rg; then
    print_success "ripgrep is already installed"
    return 0
  fi

  print_info "Installing ripgrep (fast search tool)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install ripgrep"
    return 0
  fi

  # Package name varies by distribution
  case "$PACKAGE_MANAGER" in
    apt)
      install_package ripgrep
      ;;
    dnf)
      install_package ripgrep
      ;;
    pacman)
      install_package ripgrep
      ;;
    apk)
      install_package ripgrep
      ;;
    brew)
      install_package ripgrep
      ;;
    *)
      print_warning "Cannot install ripgrep"
      return 1
      ;;
  esac

  if check_command rg; then
    print_success "ripgrep installed successfully"
  else
    print_warning "ripgrep installation failed (optional)"
  fi

  return 0
}

# ==============================================================================
# fd (fast file finder)
# ==============================================================================

install_fd() {
  if check_command fd || check_command fdfind; then
    print_success "fd is already installed"
    return 0
  fi

  print_info "Installing fd (fast file finder)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install fd"
    return 0
  fi

  # Package name varies by distribution
  case "$PACKAGE_MANAGER" in
    apt)
      install_package fd-find
      # Create alias if installed as fd-find
      if check_command fdfind && ! check_command fd; then
        print_info "Creating fd symlink for fd-find..."
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
      fi
      ;;
    dnf)
      install_package fd-find
      ;;
    pacman)
      install_package fd
      ;;
    apk)
      install_package fd
      ;;
    brew)
      install_package fd
      ;;
    *)
      print_warning "Cannot install fd"
      return 1
      ;;
  esac

  return 0
}

# ==============================================================================
# fzf (fuzzy finder)
# ==============================================================================

install_fzf() {
  if check_command fzf; then
    print_success "fzf is already installed"
    return 0
  fi

  print_info "Installing fzf (fuzzy finder)..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install fzf"
    return 0
  fi

  install_package fzf || print_warning "fzf installation failed (optional)"
  return 0
}

# ==============================================================================
# Main Installation Function
# ==============================================================================

# Install all core dependencies
# Usage: install_dependencies [--minimal]
install_dependencies() {
  local minimal="${1:-}"

  print_section "Installing Dependencies"

  # Essential dependencies (always install)
  install_git || return 1
  install_curl || return 1

  # Install unzip (needed for fonts and some downloads)
  install_unzip

  # Optional but recommended dependencies
  if [[ "$minimal" != "--minimal" ]]; then
    install_wget
    install_tig
    install_build_tools
    install_ripgrep
    install_fd
    install_fzf
  fi

  print_success "Core dependencies installed"
  return 0
}

# Check if all required dependencies are installed
# Usage: check_dependencies
# Returns: 0 if all required deps are present, 1 otherwise
check_required_dependencies() {
  local missing=()

  if ! check_command git; then
    missing+=("git")
  fi

  if ! check_command curl && ! check_command wget; then
    missing+=("curl or wget")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    print_error "Missing required dependencies: ${missing[*]}"
    return 1
  fi

  return 0
}

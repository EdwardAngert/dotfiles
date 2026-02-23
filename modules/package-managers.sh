#!/usr/bin/env bash
# modules/package-managers.sh - Package manager setup and utilities
#
# Handles detection and installation of package managers across platforms:
# - Homebrew (macOS and Linux)
# - apt (Debian/Ubuntu)
# - dnf (Fedora/RHEL)
# - pacman (Arch Linux)
# - apk (Alpine Linux)
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/modules/package-managers.sh"

# Prevent multiple sourcing
[[ -n "${_PACKAGE_MANAGERS_SH_LOADED:-}" ]] && return 0
readonly _PACKAGE_MANAGERS_SH_LOADED=1

# Ensure utils.sh is loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/package-managers.sh" >&2
  exit 1
fi

# ==============================================================================
# Package Manager Detection
# ==============================================================================

# Global variable to track detected package manager
PACKAGE_MANAGER=""

# Detect the available package manager
# Sets: PACKAGE_MANAGER variable
detect_package_manager() {
  if [[ "$OS" == "macOS" ]]; then
    if check_command brew; then
      PACKAGE_MANAGER="brew"
    fi
  elif [[ "$OS" == "Linux" ]]; then
    if check_command apt-get; then
      PACKAGE_MANAGER="apt"
    elif check_command dnf; then
      PACKAGE_MANAGER="dnf"
    elif check_command pacman; then
      PACKAGE_MANAGER="pacman"
    elif check_command apk; then
      PACKAGE_MANAGER="apk"
    elif check_command brew; then
      PACKAGE_MANAGER="brew"
    fi
  fi

  export PACKAGE_MANAGER
  print_debug "Detected package manager: ${PACKAGE_MANAGER:-none}"
}

# ==============================================================================
# Homebrew
# ==============================================================================

# Install Homebrew
# Works on both macOS and Linux
install_homebrew() {
  if check_command brew; then
    print_info "Homebrew is already installed"
    return 0
  fi

  print_info "Installing Homebrew..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Homebrew"
    return 0
  fi

  # Download and run Homebrew installer
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH based on OS and architecture
  local brew_path=""

  if [[ "$OS" == "macOS" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
      brew_path="/opt/homebrew/bin/brew"
    else
      brew_path="/usr/local/bin/brew"
    fi
  else
    brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
  fi

  if [[ -f "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"

    # Add to bash_profile for persistence
    if [[ -f "$HOME/.bash_profile" ]]; then
      echo "eval \"\$($brew_path shellenv)\"" >> "$HOME/.bash_profile"
    fi

    print_success "Homebrew installed successfully"
    PACKAGE_MANAGER="brew"
    export PACKAGE_MANAGER
    return 0
  else
    print_error "Homebrew installation failed"
    return 1
  fi
}

# ==============================================================================
# Package Manager Operations
# ==============================================================================

# Update package manager cache/index
# Usage: update_package_cache
update_package_cache() {
  print_info "Updating package manager cache..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "update package cache for $PACKAGE_MANAGER"
    return 0
  fi

  case "$PACKAGE_MANAGER" in
    apt)
      sudo apt-get update -y
      ;;
    dnf)
      sudo dnf check-update || true  # Returns non-zero if updates available
      ;;
    pacman)
      sudo pacman -Sy
      ;;
    apk)
      sudo apk update
      ;;
    brew)
      brew update
      ;;
    *)
      print_warning "Unknown package manager: $PACKAGE_MANAGER"
      return 1
      ;;
  esac

  print_success "Package cache updated"
}

# Install a package using the detected package manager
# Usage: install_package <package_name> [alternate_names...]
# alternate_names: name variations for different package managers (apt:name dnf:name etc)
install_package() {
  local package="$1"
  shift
  local alternates=("$@")
  local pkg_name="$package"

  # Check for package manager specific name
  for alt in "${alternates[@]}"; do
    local pm="${alt%%:*}"
    local name="${alt#*:}"
    if [[ "$pm" == "$PACKAGE_MANAGER" ]]; then
      pkg_name="$name"
      break
    fi
  done

  print_info "Installing $pkg_name..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install package: $pkg_name via $PACKAGE_MANAGER"
    return 0
  fi

  local result=0
  case "$PACKAGE_MANAGER" in
    apt)
      sudo apt-get install -y "$pkg_name" || result=1
      ;;
    dnf)
      sudo dnf install -y "$pkg_name" || result=1
      ;;
    pacman)
      sudo pacman -S --noconfirm "$pkg_name" || result=1
      ;;
    apk)
      sudo apk add "$pkg_name" || result=1
      ;;
    brew)
      brew install "$pkg_name" || result=1
      ;;
    *)
      print_error "No package manager available to install: $pkg_name"
      return 1
      ;;
  esac

  if [[ $result -eq 0 ]]; then
    print_success "$pkg_name installed successfully"
  else
    print_warning "Failed to install $pkg_name"
  fi

  return $result
}

# Install multiple packages at once
# Usage: install_packages <package1> <package2> ...
install_packages() {
  local packages=("$@")

  if [[ ${#packages[@]} -eq 0 ]]; then
    return 0
  fi

  print_info "Installing packages: ${packages[*]}"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install packages: ${packages[*]}"
    return 0
  fi

  case "$PACKAGE_MANAGER" in
    apt)
      sudo apt-get install -y "${packages[@]}"
      ;;
    dnf)
      sudo dnf install -y "${packages[@]}"
      ;;
    pacman)
      sudo pacman -S --noconfirm "${packages[@]}"
      ;;
    apk)
      sudo apk add "${packages[@]}"
      ;;
    brew)
      brew install "${packages[@]}"
      ;;
    *)
      print_error "No package manager available"
      return 1
      ;;
  esac
}

# Check if a package is installed
# Usage: is_package_installed <package_name>
is_package_installed() {
  local package="$1"

  case "$PACKAGE_MANAGER" in
    apt)
      dpkg -l "$package" 2>/dev/null | grep -q "^ii"
      ;;
    dnf)
      rpm -q "$package" &>/dev/null
      ;;
    pacman)
      pacman -Qi "$package" &>/dev/null
      ;;
    apk)
      apk info -e "$package" &>/dev/null
      ;;
    brew)
      brew list "$package" &>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# ==============================================================================
# Setup Functions
# ==============================================================================

# Setup package managers for the system
# Installs Homebrew if needed on macOS or if no package manager available
setup_package_managers() {
  print_section "Setting up Package Managers"

  # Detect current package manager
  detect_package_manager

  if [[ "$OS" == "macOS" ]]; then
    # macOS always uses Homebrew
    if [[ -z "$PACKAGE_MANAGER" ]]; then
      install_homebrew
    else
      print_success "Homebrew is already installed"
    fi
  elif [[ "$OS" == "Linux" ]]; then
    if [[ -n "$PACKAGE_MANAGER" ]]; then
      print_success "Using package manager: $PACKAGE_MANAGER"
      # Update cache
      update_package_cache
    else
      # No native package manager, try Homebrew
      print_info "No native package manager found, installing Homebrew..."
      install_homebrew
    fi
  fi

  # Re-detect after potential installation
  detect_package_manager

  if [[ -z "$PACKAGE_MANAGER" ]]; then
    print_error "No package manager available. Cannot continue."
    return 1
  fi

  return 0
}

# ==============================================================================
# Snap Support (optional fallback)
# ==============================================================================

# Check if snap is available
has_snap() {
  check_command snap && [[ -d /snap ]]
}

# Install a package via snap
# Usage: install_snap <package_name> [--classic]
install_snap() {
  local package="$1"
  local classic="${2:-}"

  if ! has_snap; then
    print_warning "Snap is not available on this system"
    return 1
  fi

  print_info "Installing $package via snap..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "snap install $package $classic"
    return 0
  fi

  if [[ "$classic" == "--classic" ]]; then
    sudo snap install "$package" --classic
  else
    sudo snap install "$package"
  fi
}

# ==============================================================================
# Initialization
# ==============================================================================

# Auto-detect package manager on load
detect_package_manager

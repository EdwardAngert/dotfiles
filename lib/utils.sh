#!/usr/bin/env bash
# lib/utils.sh - Shared utility functions for dotfiles installation
#
# This library provides common functions used across all installation scripts.
# Source this file at the beginning of any script that needs these utilities.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"
#   # or
#   source "$DOTFILES_DIR/lib/utils.sh"

# Prevent multiple sourcing
[[ -n "${_UTILS_SH_LOADED:-}" ]] && return 0
readonly _UTILS_SH_LOADED=1

# ==============================================================================
# Colors
# ==============================================================================

# Only use colors if stdout is a terminal
if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly MAGENTA='\033[0;35m'
  readonly CYAN='\033[0;36m'
  readonly BOLD='\033[1m'
  readonly NC='\033[0m' # No Color
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly MAGENTA=''
  readonly CYAN=''
  readonly BOLD=''
  readonly NC=''
fi

# ==============================================================================
# Global Variables
# ==============================================================================

# Dry run mode - when true, operations are logged but not executed
DRY_RUN="${DRY_RUN:-false}"

# Verbose mode - when true, more detailed output is shown
VERBOSE="${VERBOSE:-false}"

# ==============================================================================
# Printing Functions
# ==============================================================================

# Print an informational message
print_info() {
  echo -e "${BLUE}INFO:${NC} $1"
}

# Print a success message
print_success() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

# Print a warning message
print_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

# Print an error message
print_error() {
  echo -e "${RED}ERROR:${NC} $1"
}

# Print a debug message (only shown in verbose mode)
print_debug() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${CYAN}DEBUG:${NC} $1"
  fi
}

# Print a dry-run message
print_dry_run() {
  echo -e "${MAGENTA}[DRY-RUN]${NC} Would $1"
}

# Print a section header
print_section() {
  echo ""
  echo -e "${BOLD}${BLUE}=== $1 ===${NC}"
  echo ""
}

# ==============================================================================
# Command Checking
# ==============================================================================

# Check if a command exists
# Usage: check_command <command_name>
# Returns: 0 if command exists, 1 if not, 2 if no argument provided
check_command() {
  if [[ -z "${1:-}" ]]; then
    print_error "No command specified for check_command"
    return 2
  fi

  if command -v "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Require a command to exist, exit if it doesn't
# Usage: require_command <command_name> [error_message]
require_command() {
  local cmd="$1"
  local msg="${2:-$cmd is required but not installed}"

  if ! check_command "$cmd"; then
    print_error "$msg"
    exit 1
  fi
}

# ==============================================================================
# OS Detection
# ==============================================================================

# Detect operating system
# Sets global OS variable to: macOS, Linux, or Unknown
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
  else
    OS="Unknown"
    print_warning "Unsupported OS detected: $OSTYPE. Some features may not work properly."
  fi
  export OS
}

# Detect Linux distribution
# Sets global DISTRO variable
detect_distro() {
  if [[ "$OS" != "Linux" ]]; then
    DISTRO="N/A"
    export DISTRO
    return
  fi

  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO="${ID:-unknown}"
  elif check_command lsb_release; then
    DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
  else
    DISTRO="unknown"
  fi
  export DISTRO
}

# Detect architecture
# Sets global ARCH variable to normalized architecture name
detect_arch() {
  local raw_arch
  raw_arch=$(uname -m)

  case "$raw_arch" in
    x86_64|amd64)
      ARCH="x86_64"
      ;;
    aarch64|arm64)
      ARCH="arm64"
      ;;
    armv7l|armhf)
      ARCH="arm32"
      ;;
    *)
      ARCH="$raw_arch"
      ;;
  esac
  export ARCH
}

# ==============================================================================
# Directory Functions
# ==============================================================================

# Get the dotfiles directory (where this repo is located)
# This resolves symlinks to find the actual directory
get_dotfiles_dir() {
  local script_path="${BASH_SOURCE[1]:-$0}"
  local dir

  # Resolve symlinks
  while [[ -L "$script_path" ]]; do
    dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    script_path="$(readlink "$script_path")"
    [[ "$script_path" != /* ]] && script_path="$dir/$script_path"
  done

  dir="$(cd -P "$(dirname "$script_path")" && pwd)"

  # If we're in lib/ or modules/, go up one level
  if [[ "$(basename "$dir")" == "lib" ]] || [[ "$(basename "$dir")" == "modules" ]]; then
    dir="$(dirname "$dir")"
  fi

  echo "$dir"
}

# Create directory safely with dry-run support
# Usage: safe_mkdir <directory>
safe_mkdir() {
  local dir="$1"

  if [[ -d "$dir" ]]; then
    print_debug "Directory already exists: $dir"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "create directory: $dir"
    return 0
  fi

  if mkdir -p "$dir"; then
    print_debug "Created directory: $dir"
    return 0
  else
    print_error "Failed to create directory: $dir"
    return 1
  fi
}

# ==============================================================================
# File Operations with Dry-Run Support
# ==============================================================================

# Create a symlink safely with dry-run support
# Usage: safe_symlink <source> <target>
safe_symlink() {
  local source="$1"
  local target="$2"

  # Verify source exists
  if [[ ! -e "$source" ]]; then
    print_error "Source does not exist: $source"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "symlink: $target -> $source"
    return 0
  fi

  # Remove existing target if it's a symlink or file
  if [[ -L "$target" ]] || [[ -f "$target" ]]; then
    rm -f "$target"
  fi

  # Create parent directory if needed
  safe_mkdir "$(dirname "$target")"

  if ln -sf "$source" "$target"; then
    print_debug "Created symlink: $target -> $source"
    return 0
  else
    print_error "Failed to create symlink: $target -> $source"
    return 1
  fi
}

# Copy a file safely with dry-run support
# Usage: safe_copy <source> <target>
safe_copy() {
  local source="$1"
  local target="$2"

  # Verify source exists
  if [[ ! -e "$source" ]]; then
    print_error "Source does not exist: $source"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "copy: $source -> $target"
    return 0
  fi

  # Create parent directory if needed
  safe_mkdir "$(dirname "$target")"

  if cp -f "$source" "$target"; then
    print_debug "Copied: $source -> $target"
    return 0
  else
    print_error "Failed to copy: $source -> $target"
    return 1
  fi
}

# Remove a file or directory safely with dry-run support
# Usage: safe_remove <path>
safe_remove() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
    print_debug "Path does not exist (nothing to remove): $path"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "remove: $path"
    return 0
  fi

  if rm -rf "$path"; then
    print_debug "Removed: $path"
    return 0
  else
    print_error "Failed to remove: $path"
    return 1
  fi
}

# ==============================================================================
# Backup Functions (simple version - see lib/backup.sh for registry support)
# ==============================================================================

# Backup a file or directory if it exists
# Usage: backup_if_exists <path>
# Returns: 0 if backup created, 1 if path didn't exist, 2 on error
backup_if_exists() {
  local path="$1"
  local backup_path="${path}.backup.$(date +%Y%m%d_%H%M%S)"

  if [[ ! -e "$path" ]]; then
    print_debug "Nothing to backup (doesn't exist): $path"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "backup: $path -> $backup_path"
    return 0
  fi

  print_info "Backing up: $path -> $backup_path"

  if mv "$path" "$backup_path"; then
    print_success "Backup created: $backup_path"
    return 0
  else
    print_error "Failed to create backup of $path. Check permissions."
    return 2
  fi
}

# ==============================================================================
# Version Comparison
# ==============================================================================

# Compare two version strings
# Usage: version_compare <version1> <version2>
# Returns: 0 if v1 >= v2, 1 if v1 < v2
version_compare() {
  local v1="$1"
  local v2="$2"

  # Remove leading 'v' if present
  v1="${v1#v}"
  v2="${v2#v}"

  if [[ "$v1" == "$v2" ]]; then
    return 0
  fi

  # Sort versions and check if v1 comes after v2
  local sorted
  sorted=$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)

  if [[ "$sorted" == "$v2" ]]; then
    return 0  # v1 >= v2
  else
    return 1  # v1 < v2
  fi
}

# ==============================================================================
# User Interaction
# ==============================================================================

# Ask user for confirmation
# Usage: confirm <prompt> [default: y/n]
# Returns: 0 for yes, 1 for no
confirm() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "$default" == "y" ]]; then
    prompt="$prompt [Y/n] "
  else
    prompt="$prompt [y/N] "
  fi

  # In non-interactive mode, use default
  if [[ ! -t 0 ]]; then
    [[ "$default" == "y" ]]
    return $?
  fi

  read -r -p "$prompt" reply
  reply="${reply:-$default}"

  case "$reply" in
    [Yy]*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ==============================================================================
# Initialization
# ==============================================================================

# Run detection functions on load
detect_os
detect_arch

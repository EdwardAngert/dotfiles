#!/usr/bin/env bash
# nvim/upgrade-nvim.sh - Upgrade Neovim to latest stable version
#
# This script upgrades Neovim to the latest stable release, which is
# especially useful for remote environments where the system package is outdated.

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

# Source neovim module for shared functions
source "$DOTFILES_DIR/modules/package-managers.sh"
source "$DOTFILES_DIR/modules/neovim.sh"

# ==============================================================================
# Configuration
# ==============================================================================

NON_INTERACTIVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      NON_INTERACTIVE=true
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --non-interactive  Run without prompting (for automated scripts)"
      echo "  --help             Show this help message"
      exit 0
      ;;
    *)
      print_error "Unknown parameter: $1"
      exit 1
      ;;
  esac
  shift
done

# ==============================================================================
# Main
# ==============================================================================

main() {
  # Check current version
  if check_nvim_version; then
    local current
    current=$(get_nvim_version)
    print_success "Neovim v$current meets required version $NVIM_MIN_VERSION"

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      return 0
    fi

    if ! confirm "Do you want to upgrade anyway?"; then
      return 0
    fi
  fi

  # Need to upgrade
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    print_info "Upgrading Neovim automatically..."
    upgrade_neovim
  else
    if confirm "Do you want to install/upgrade Neovim?"; then
      upgrade_neovim
    else
      print_warning "Skipping Neovim upgrade. Some plugins might not work properly."
    fi
  fi
}

main "$@"

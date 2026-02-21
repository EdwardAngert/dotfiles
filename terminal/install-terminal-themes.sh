#!/usr/bin/env bash
# terminal/install-terminal-themes.sh - Install terminal themes
#
# This script installs Catppuccin Mocha theme for various terminal emulators.

set -eo pipefail

# ==============================================================================
# Initialization
# ==============================================================================

# Determine script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/backup.sh"
source "$DOTFILES_DIR/modules/package-managers.sh"
source "$DOTFILES_DIR/modules/terminal.sh"

# ==============================================================================
# Configuration
# ==============================================================================

UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
  print_info "Running in update mode - will overwrite existing configurations"
fi

# Determine backup behavior
BACKUP_FLAG=""
if [[ "$UPDATE_MODE" != "true" ]]; then
  BACKUP_FLAG="--backup"
  print_info "Regular mode: Will backup existing configurations"
fi

# ==============================================================================
# Main
# ==============================================================================

main() {
  terminal_setup "$DOTFILES_DIR" "$BACKUP_FLAG"
}

main "$@"

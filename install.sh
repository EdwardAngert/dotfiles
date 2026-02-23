#!/bin/bash
# install.sh - Dotfiles installation orchestrator
#
# This script coordinates the installation of all dotfiles components
# by sourcing modular libraries and calling their functions.
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   --skip-fonts     Skip font installation
#   --skip-neovim    Skip Neovim configuration
#   --skip-zsh       Skip Zsh configuration
#   --skip-vscode    Skip VSCode configuration
#   --skip-terminal  Skip terminal configuration
#   --update         Update mode - skip dependency installation, only update configs
#   --pull           Pull latest changes from git repository before installing
#   --setup-auto-update  Configure automatic weekly updates via cron
#   --dry-run        Show what would be done without making changes
#   --rollback       Rollback to previous configuration
#   --help           Show this help message

set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# Initialization
# ==============================================================================

# Start timing
START_TIME=$(date +%s)

# Determine dotfiles directory (resolving symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DOTFILES_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"

# ==============================================================================
# Source Libraries
# ==============================================================================

source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/network.sh"
source "$DOTFILES_DIR/lib/backup.sh"

# ==============================================================================
# Source Modules
# ==============================================================================

source "$DOTFILES_DIR/modules/package-managers.sh"
source "$DOTFILES_DIR/modules/dependencies.sh"
source "$DOTFILES_DIR/modules/nodejs.sh"
source "$DOTFILES_DIR/modules/neovim.sh"
source "$DOTFILES_DIR/modules/zsh.sh"
source "$DOTFILES_DIR/modules/link-configs.sh"
source "$DOTFILES_DIR/modules/vscode.sh"
source "$DOTFILES_DIR/modules/terminal.sh"

# ==============================================================================
# CLI Options
# ==============================================================================

SKIP_FONTS=false
SKIP_NEOVIM=false
SKIP_ZSH=false
SKIP_VSCODE=false
SKIP_TERMINAL=false
UPDATE_MODE=false
DO_ROLLBACK=false

# Parse command line arguments
parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --skip-fonts) SKIP_FONTS=true ;;
      --skip-neovim) SKIP_NEOVIM=true ;;
      --skip-zsh) SKIP_ZSH=true ;;
      --skip-vscode) SKIP_VSCODE=true ;;
      --skip-terminal) SKIP_TERMINAL=true ;;
      --update) UPDATE_MODE=true ;;
      --dry-run) DRY_RUN=true ;;
      --rollback) DO_ROLLBACK=true ;;
      --pull)
        print_info "Pulling latest changes from git repository..."
        git -C "$DOTFILES_DIR" pull
        print_success "Repository updated to latest version"
        ;;
      --setup-auto-update)
        setup_auto_update
        exit 0
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        print_error "Unknown parameter: $1"
        echo "Run '$0 --help' for usage information"
        exit 1
        ;;
    esac
    shift
  done
}

show_help() {
  cat << EOF
Usage: $0 [options]

Options:
  --skip-fonts        Skip font installation
  --skip-neovim       Skip Neovim configuration
  --skip-zsh          Skip Zsh configuration
  --skip-vscode       Skip VSCode configuration
  --skip-terminal     Skip terminal configuration
  --update            Update mode - skip dependency installation, only update configs
  --pull              Pull latest changes from git repository before installing
  --setup-auto-update Configure automatic weekly updates via cron
  --dry-run           Show what would be done without making changes
  --rollback          Rollback to previous configuration
  --help              Show this help message

Examples:
  Fresh install:           $0
  Update existing:         $0 --update
  Pull and update:         $0 --pull --update
  Preview changes:         $0 --dry-run
  Rollback last changes:   $0 --rollback
  Skip some components:    $0 --skip-fonts --skip-vscode

For more information, see README.md
EOF
}

setup_auto_update() {
  print_info "Setting up automatic updates..."

  local auto_update_script="$HOME/.local/bin/update-dotfiles.sh"
  safe_mkdir "$(dirname "$auto_update_script")"

  cat > "$auto_update_script" << EOF
#!/bin/bash
cd "$DOTFILES_DIR" && ./install.sh --pull --update
EOF
  chmod +x "$auto_update_script"

  # Set up weekly cron job
  (crontab -l 2>/dev/null || echo "") | grep -v "update-dotfiles.sh" | \
    { cat; echo "0 12 * * 0 $auto_update_script"; } | crontab -

  print_success "Automatic weekly updates configured!"
  print_info "Updates will run every Sunday at noon."
  print_info "To manually trigger an update, run: $auto_update_script"
}

# ==============================================================================
# Signal Handling
# ==============================================================================

cleanup() {
  # Remove any temporary files
  :
}

trap 'cleanup; echo -e "\n${RED:-}Script interrupted. Exiting...${NC:-}"; exit 1' INT TERM
trap 'cleanup' EXIT
trap 'print_error "Command failed at line $LINENO: $BASH_COMMAND"' ERR

# ==============================================================================
# Main Installation
# ==============================================================================

run_installation() {
  print_section "Dotfiles Installation"
  print_info "Detected OS: $OS ($ARCH)"
  print_info "Dotfiles directory: $DOTFILES_DIR"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warning "DRY RUN MODE - No changes will be made"
  fi

  # Initialize backup session
  init_backup_session "install"

  # Determine if we should backup
  local backup_flag=""
  if [[ "$UPDATE_MODE" != "true" ]]; then
    backup_flag="--backup"
    print_info "Will automatically backup any existing configurations"
  else
    print_info "Update mode: Will overwrite existing configurations"
  fi

  # Setup package managers and install dependencies (skip in update mode)
  if [[ "$UPDATE_MODE" != "true" ]]; then
    setup_package_managers
    install_dependencies
  else
    # Re-detect package manager even in update mode
    detect_package_manager
  fi

  # Git configuration
  link_git_config "$DOTFILES_DIR"

  # Node.js (needed for Neovim CoC)
  if [[ "$SKIP_NEOVIM" != "true" ]] && [[ "$UPDATE_MODE" != "true" ]]; then
    install_nodejs
  fi

  # Neovim
  if [[ "$SKIP_NEOVIM" != "true" ]]; then
    if [[ "$UPDATE_MODE" == "true" ]]; then
      # In update mode, just update plugins
      install_nvim_plugins --update
      install_coc_extensions --update
    else
      install_neovim
    fi
    link_nvim_config "$DOTFILES_DIR" "$backup_flag"
  fi

  # Zsh
  if [[ "$SKIP_ZSH" != "true" ]]; then
    if [[ "$UPDATE_MODE" != "true" ]]; then
      zsh_setup "$DOTFILES_DIR"
    else
      zsh_update
    fi
    link_zsh_config "$DOTFILES_DIR" "$backup_flag"
  fi

  # VSCode
  if [[ "$SKIP_VSCODE" != "true" ]]; then
    vscode_setup "$DOTFILES_DIR" "$backup_flag"
  fi

  # Fonts
  if [[ "$SKIP_FONTS" != "true" ]]; then
    print_section "Installing Fonts"
    local font_args=()
    [[ "$UPDATE_MODE" == "true" ]] && font_args+=(--update)
    [[ "$DRY_RUN" == "true" ]] && font_args+=(--dry-run)
    "$DOTFILES_DIR/fonts/install-fonts.sh" "${font_args[@]}"
  fi

  # Terminal
  if [[ "$SKIP_TERMINAL" != "true" ]]; then
    terminal_setup "$DOTFILES_DIR" "$backup_flag"
  fi

  # GitHub CLI
  if [[ -f "$DOTFILES_DIR/github/install-github-cli.sh" ]]; then
    print_section "Setting up GitHub CLI"
    local gh_args=(--non-interactive)
    [[ "$UPDATE_MODE" == "true" ]] && gh_args+=(--update)
    [[ "$DRY_RUN" == "true" ]] && gh_args+=(--dry-run)
    "$DOTFILES_DIR/github/install-github-cli.sh" "${gh_args[@]}" || \
      print_warning "GitHub CLI setup had issues (non-fatal)"
  fi

  # Cleanup old backups (keep last 5)
  cleanup_old_backups 5
}

run_rollback() {
  print_section "Rollback"

  # List available sessions
  list_backup_sessions

  echo ""

  # Perform rollback
  rollback_session
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
  print_section "Installation Summary"

  # Build status list
  local summary=""

  # Zsh status
  if check_command zsh; then
    summary+="\n${GREEN:-}✓${NC:-} Zsh is available"
  else
    summary+="\n${RED:-}✗${NC:-} Zsh was not installed properly"
  fi

  # Neovim status
  if check_command nvim; then
    summary+="\n${GREEN:-}✓${NC:-} Neovim is available"
  else
    summary+="\n${RED:-}✗${NC:-} Neovim was not installed properly"
  fi

  # Tig status
  if check_command tig; then
    summary+="\n${GREEN:-}✓${NC:-} Tig is available"
  else
    summary+="\n${RED:-}✗${NC:-} Tig was not installed properly"
  fi

  # Config files
  if [[ -f "$HOME/.config/nvim/init.vim" ]]; then
    summary+="\n${GREEN:-}✓${NC:-} Neovim configuration is in place"
  else
    summary+="\n${RED:-}✗${NC:-} Neovim configuration is missing"
  fi

  if [[ -f "$HOME/.zshrc" ]]; then
    summary+="\n${GREEN:-}✓${NC:-} Zsh configuration is in place"
  else
    summary+="\n${RED:-}✗${NC:-} Zsh configuration is missing"
  fi

  # Node.js status
  if check_command node; then
    summary+="\n${GREEN:-}✓${NC:-} Node.js is available (for Neovim CoC)"
  else
    summary+="\n${YELLOW:-}○${NC:-} Node.js is not available (Neovim CoC disabled)"
  fi

  # Git config
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    summary+="\n${GREEN:-}✓${NC:-} Git local configuration is in place"
  else
    summary+="\n${YELLOW:-}○${NC:-} Git local configuration is missing"
  fi

  # GitHub CLI
  if check_command gh; then
    if gh auth status &>/dev/null; then
      summary+="\n${GREEN:-}✓${NC:-} GitHub CLI is installed and authenticated"
    else
      summary+="\n${YELLOW:-}○${NC:-} GitHub CLI is installed but not authenticated"
    fi
  else
    summary+="\n${YELLOW:-}○${NC:-} GitHub CLI is not installed"
  fi

  # VSCode extensions (if VSCode is installed)
  if check_command code; then
    if code --list-extensions 2>/dev/null | grep -q "catppuccin.catppuccin-vsc"; then
      summary+="\n${GREEN:-}✓${NC:-} VSCode Catppuccin theme is installed"
    else
      summary+="\n${YELLOW:-}○${NC:-} VSCode Catppuccin theme not found"
    fi
  fi

  echo -e "$summary"

  # Calculate and display execution time
  local end_time
  end_time=$(date +%s)
  local execution_time=$((end_time - START_TIME))
  local minutes=$((execution_time / 60))
  local seconds=$((execution_time % 60))

  echo ""
  if [[ "$UPDATE_MODE" == "true" ]]; then
    print_success "Update completed in ${minutes}m ${seconds}s"
  else
    print_success "Installation completed in ${minutes}m ${seconds}s"
  fi

  # Post-install notes
  echo ""
  print_info "Note: You may need to restart your terminal to see all changes."
  print_info "To apply zsh changes without restarting: source ~/.zshrc"

  if [[ "$UPDATE_MODE" == "true" ]]; then
    echo ""
    print_info "To set up automated weekly updates, run: $0 --setup-auto-update"
  fi
}

# ==============================================================================
# Entry Point
# ==============================================================================

main() {
  parse_arguments "$@"

  if [[ "$DO_ROLLBACK" == "true" ]]; then
    run_rollback
  else
    run_installation
    print_summary
  fi
}

main "$@"

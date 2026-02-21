#!/usr/bin/env bash
# modules/link-configs.sh - Configuration file symlinking
#
# Handles creating symlinks for all configuration files:
# - Neovim configuration
# - Zsh configuration
# - Git configuration
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/lib/backup.sh"
#   source "$DOTFILES_DIR/modules/link-configs.sh"

# Prevent multiple sourcing
[[ -n "${_LINK_CONFIGS_SH_LOADED:-}" ]] && return 0
readonly _LINK_CONFIGS_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/link-configs.sh" >&2
  exit 1
fi

# ==============================================================================
# Neovim Configuration
# ==============================================================================

# Select Neovim template based on system capabilities
# Usage: select_nvim_template <dotfiles_dir>
# Outputs: template filename or empty string
select_nvim_template() {
  local dotfiles_dir="$1"
  local template=""

  # Check for available templates
  local has_default=false
  local has_catppuccin=false
  local has_monokai=false
  local has_nolua=false
  local has_nococ=false

  [[ -f "$dotfiles_dir/nvim/personal.vim.template" ]] && has_default=true
  [[ -f "$dotfiles_dir/nvim/personal.catppuccin.vim" ]] && has_catppuccin=true
  [[ -f "$dotfiles_dir/nvim/personal.monokai.vim" ]] && has_monokai=true
  [[ -f "$dotfiles_dir/nvim/personal.nolua.vim" ]] && has_nolua=true
  [[ -f "$dotfiles_dir/nvim/personal.nococ.vim" ]] && has_nococ=true

  # Check system capabilities
  local has_lua=false
  local has_node=false

  if check_command nvim; then
    # Check for Lua support
    if nvim --version | grep -q "LuaJIT"; then
      has_lua=true
    fi
  fi

  if check_command node; then
    has_node=true
  fi

  # Check for no-coc marker
  if [[ -f "$HOME/.config/nvim/.no-coc" ]]; then
    has_node=false
  fi

  # Select template based on capabilities
  if [[ "$has_lua" == "false" ]] && [[ "$has_nolua" == "true" ]]; then
    template="personal.nolua.vim"
    print_info "Using no-Lua configuration (Neovim lacks Lua support)"
  elif [[ "$has_node" == "false" ]] && [[ "$has_nococ" == "true" ]]; then
    template="personal.nococ.vim"
    print_info "Using no-CoC configuration (Node.js not available)"
  elif [[ "$has_catppuccin" == "true" ]]; then
    template="personal.catppuccin.vim"
    print_info "Using Catppuccin theme configuration"
  elif [[ "$has_default" == "true" ]]; then
    template="personal.vim.template"
  fi

  echo "$template"
}

# Link Neovim configuration
# Usage: link_nvim_config <dotfiles_dir> [--backup]
link_nvim_config() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local nvim_config_dir="$HOME/.config/nvim"
  local nvim_init="$nvim_config_dir/init.vim"
  local personal_vim="$nvim_config_dir/personal.vim"

  print_info "Setting up Neovim configuration..."

  # Check if source exists
  if [[ ! -f "$dotfiles_dir/nvim/init.vim" ]]; then
    print_error "Neovim config file not found: $dotfiles_dir/nvim/init.vim"
    return 1
  fi

  # Backup existing config if requested
  if [[ "$should_backup" == "--backup" ]]; then
    if [[ -d "$nvim_config_dir" ]]; then
      backup_with_registry "$nvim_config_dir" || backup_if_exists "$nvim_config_dir" || true
    fi
  fi

  # Create config directory
  safe_mkdir "$nvim_config_dir"

  # Create symlink for init.vim
  if safe_symlink "$dotfiles_dir/nvim/init.vim" "$nvim_init"; then
    print_success "Neovim config linked"
  else
    print_error "Failed to link Neovim config"
    return 1
  fi

  # Setup personal.vim if it doesn't exist
  if [[ ! -f "$personal_vim" ]]; then
    local template
    template=$(select_nvim_template "$dotfiles_dir")

    if [[ -n "$template" ]] && [[ -f "$dotfiles_dir/nvim/$template" ]]; then
      if safe_copy "$dotfiles_dir/nvim/$template" "$personal_vim"; then
        print_success "Created $personal_vim"
      fi
    fi
  fi

  return 0
}

# ==============================================================================
# Zsh Configuration
# ==============================================================================

# Link Zsh configuration
# Usage: link_zsh_config <dotfiles_dir> [--backup]
link_zsh_config() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local zshrc="$HOME/.zshrc"
  local zshrc_local="$HOME/.zshrc.local"

  print_info "Setting up Zsh configuration..."

  # Check if source exists
  if [[ ! -f "$dotfiles_dir/zsh/.zshrc" ]]; then
    print_error "Zsh config file not found: $dotfiles_dir/zsh/.zshrc"
    return 1
  fi

  # Backup existing config if requested
  if [[ "$should_backup" == "--backup" ]]; then
    backup_with_registry "$zshrc" || backup_if_exists "$zshrc" || true
  fi

  # Create symlink for .zshrc
  if safe_symlink "$dotfiles_dir/zsh/.zshrc" "$zshrc"; then
    print_success "Zsh config linked"
  else
    print_error "Failed to link Zsh config"
    return 1
  fi

  # Create .zshrc.local template if it doesn't exist
  if [[ ! -f "$zshrc_local" ]] && [[ -f "$dotfiles_dir/zsh/.zshrc.local.template" ]]; then
    if safe_copy "$dotfiles_dir/zsh/.zshrc.local.template" "$zshrc_local"; then
      print_info "Created $zshrc_local template for custom configuration"
    fi
  fi

  return 0
}

# ==============================================================================
# Git Configuration
# ==============================================================================

# Link Git configuration
# Usage: link_git_config <dotfiles_dir>
link_git_config() {
  local dotfiles_dir="$1"
  local gitconfig_local="$HOME/.gitconfig.local"

  # Create gitconfig.local from template if it doesn't exist
  if [[ ! -f "$gitconfig_local" ]] && [[ -f "$dotfiles_dir/gitconfig.local.template" ]]; then
    print_info "Creating git local configuration template..."

    if safe_copy "$dotfiles_dir/gitconfig.local.template" "$gitconfig_local"; then
      print_success "Created $gitconfig_local template - edit this file to set your git identity"
    fi
  fi

  return 0
}

# ==============================================================================
# iTerm2 Shell Integration
# ==============================================================================

# Link iTerm2 shell integration
# Usage: link_iterm_integration <dotfiles_dir>
link_iterm_integration() {
  local dotfiles_dir="$1"
  local iterm_integration="$HOME/.iterm2_shell_integration.zsh"
  local source_file="$dotfiles_dir/iterm/.iterm2_shell_integration.zsh"

  if [[ ! -f "$source_file" ]]; then
    return 0
  fi

  if [[ -f "$iterm_integration" ]]; then
    print_debug "iTerm2 shell integration already exists"
    return 0
  fi

  print_info "Linking iTerm2 shell integration..."

  safe_symlink "$source_file" "$iterm_integration"
}

# ==============================================================================
# Alacritty Configuration
# ==============================================================================

# Link Alacritty configuration
# Usage: link_alacritty_config <dotfiles_dir> [--backup]
link_alacritty_config() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local alacritty_dir="$HOME/.config/alacritty"
  local alacritty_config="$alacritty_dir/alacritty.yml"
  local source_file="$dotfiles_dir/terminal/alacritty.yml"

  if [[ ! -f "$source_file" ]]; then
    return 0
  fi

  if ! check_command alacritty; then
    return 0
  fi

  print_info "Setting up Alacritty configuration..."

  # Backup if requested
  if [[ "$should_backup" == "--backup" ]] && [[ -f "$alacritty_config" ]]; then
    backup_with_registry "$alacritty_config" || backup_if_exists "$alacritty_config" || true
  fi

  safe_mkdir "$alacritty_dir"
  safe_copy "$source_file" "$alacritty_config"

  print_success "Alacritty configuration installed"
}

# ==============================================================================
# Main Linking Function
# ==============================================================================

# Link all configuration files
# Usage: link_configs <dotfiles_dir> [--backup] [--update]
link_configs() {
  local dotfiles_dir="$1"
  shift

  local backup_flag=""
  local update_mode=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backup) backup_flag="--backup" ;;
      --update) update_mode="true" ;;
      *) ;;
    esac
    shift
  done

  print_section "Linking Configuration Files"

  # Determine backup behavior
  if [[ "$update_mode" == "true" ]]; then
    print_info "Update mode: Will overwrite existing configurations"
    backup_flag=""
  elif [[ -n "$backup_flag" ]]; then
    print_info "Will backup any existing configurations"
  fi

  # Link all configurations
  link_nvim_config "$dotfiles_dir" "$backup_flag"
  link_zsh_config "$dotfiles_dir" "$backup_flag"
  link_git_config "$dotfiles_dir"
  link_iterm_integration "$dotfiles_dir"
  link_alacritty_config "$dotfiles_dir" "$backup_flag"

  print_success "Configuration files linked"
}

# ==============================================================================
# Verification
# ==============================================================================

# Verify all configuration links are in place
# Usage: verify_configs
verify_configs() {
  local all_good=true

  print_info "Verifying configuration links..."

  # Check Neovim config
  if [[ -f "$HOME/.config/nvim/init.vim" ]]; then
    print_success "Neovim configuration is in place"
  else
    print_warning "Neovim configuration is missing"
    all_good=false
  fi

  # Check Zsh config
  if [[ -f "$HOME/.zshrc" ]]; then
    print_success "Zsh configuration is in place"
  else
    print_warning "Zsh configuration is missing"
    all_good=false
  fi

  # Check Git config
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    print_success "Git local configuration is in place"
  else
    print_warning "Git local configuration is missing"
    all_good=false
  fi

  if [[ "$all_good" == "true" ]]; then
    return 0
  else
    return 1
  fi
}

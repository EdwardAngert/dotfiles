#!/usr/bin/env bash
# modules/zsh.sh - Zsh installation and configuration
#
# Handles:
# - Zsh shell installation
# - Oh My Zsh framework
# - Zsh plugins (autosuggestions, syntax-highlighting)
# - Powerlevel10k theme
# - Shell change to zsh
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/modules/package-managers.sh"
#   source "$DOTFILES_DIR/modules/zsh.sh"

# Prevent multiple sourcing
[[ -n "${_ZSH_SH_LOADED:-}" ]] && return 0
readonly _ZSH_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/zsh.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# Oh My Zsh directory
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

# ==============================================================================
# Zsh Installation
# ==============================================================================

# Install Zsh shell
install_zsh() {
  if check_command zsh; then
    print_success "Zsh is already installed"
    return 0
  fi

  print_info "Installing Zsh..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Zsh"
    return 0
  fi

  if install_package zsh; then
    if check_command zsh; then
      print_success "Zsh installed successfully"
      return 0
    fi
  fi

  print_error "Failed to install Zsh"
  return 1
}

# ==============================================================================
# Oh My Zsh
# ==============================================================================

# Install Oh My Zsh framework
install_oh_my_zsh() {
  if [[ -d "$ZSH" ]]; then
    print_success "Oh My Zsh is already installed"
    return 0
  fi

  print_info "Installing Oh My Zsh..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Oh My Zsh"
    return 0
  fi

  if ! check_command git; then
    print_error "Git is required to install Oh My Zsh"
    return 1
  fi

  # Clone Oh My Zsh (avoiding the install script which changes shell)
  if git clone https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"; then
    print_success "Oh My Zsh installed successfully"

    # Create custom directories
    mkdir -p "$ZSH_CUSTOM/plugins"
    mkdir -p "$ZSH_CUSTOM/themes"

    return 0
  else
    print_error "Failed to clone Oh My Zsh repository"
    return 1
  fi
}

# Update Oh My Zsh
update_oh_my_zsh() {
  if [[ ! -d "$ZSH" ]]; then
    print_warning "Oh My Zsh not installed"
    return 1
  fi

  print_info "Updating Oh My Zsh..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "update Oh My Zsh"
    return 0
  fi

  (cd "$ZSH" && git pull --rebase --quiet)
  print_success "Oh My Zsh updated"
}

# ==============================================================================
# Zsh Plugins
# ==============================================================================

# Install zsh-autosuggestions plugin
install_zsh_autosuggestions() {
  local plugin_dir="$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  if [[ -d "$plugin_dir" ]]; then
    print_success "zsh-autosuggestions is already installed"
    return 0
  fi

  print_info "Installing zsh-autosuggestions plugin..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install zsh-autosuggestions"
    return 0
  fi

  mkdir -p "$ZSH_CUSTOM/plugins"

  if git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"; then
    print_success "zsh-autosuggestions installed"
    return 0
  else
    print_error "Failed to install zsh-autosuggestions"
    return 1
  fi
}

# Install zsh-syntax-highlighting plugin
install_zsh_syntax_highlighting() {
  local plugin_dir="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  if [[ -d "$plugin_dir" ]]; then
    print_success "zsh-syntax-highlighting is already installed"
    return 0
  fi

  print_info "Installing zsh-syntax-highlighting plugin..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install zsh-syntax-highlighting"
    return 0
  fi

  mkdir -p "$ZSH_CUSTOM/plugins"

  if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir"; then
    print_success "zsh-syntax-highlighting installed"
    return 0
  else
    print_error "Failed to install zsh-syntax-highlighting"
    return 1
  fi
}

# Install all Zsh plugins
install_zsh_plugins() {
  print_info "Installing Zsh plugins..."

  install_zsh_autosuggestions
  install_zsh_syntax_highlighting

  print_success "Zsh plugins installed"
}

# Update Zsh plugins
update_zsh_plugins() {
  print_info "Updating Zsh plugins..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "update Zsh plugins"
    return 0
  fi

  local plugin_dir
  for plugin_dir in "$ZSH_CUSTOM/plugins"/*/; do
    [[ ! -d "$plugin_dir/.git" ]] && continue

    local plugin_name
    plugin_name=$(basename "$plugin_dir")
    print_debug "Updating plugin: $plugin_name"
    (cd "$plugin_dir" && git pull --rebase --quiet) || true
  done

  print_success "Zsh plugins updated"
}

# ==============================================================================
# Powerlevel10k Theme
# ==============================================================================

# Install Powerlevel10k theme
install_powerlevel10k() {
  local theme_dir="$ZSH_CUSTOM/themes/powerlevel10k"

  if [[ -d "$theme_dir" ]]; then
    print_success "Powerlevel10k is already installed"
    return 0
  fi

  print_info "Installing Powerlevel10k theme..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install Powerlevel10k"
    return 0
  fi

  mkdir -p "$ZSH_CUSTOM/themes"

  if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"; then
    print_success "Powerlevel10k theme installed"
    return 0
  else
    print_error "Failed to install Powerlevel10k"
    return 1
  fi
}

# Update Powerlevel10k theme
update_powerlevel10k() {
  local theme_dir="$ZSH_CUSTOM/themes/powerlevel10k"

  if [[ ! -d "$theme_dir" ]]; then
    return 0
  fi

  print_info "Updating Powerlevel10k theme..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "update Powerlevel10k"
    return 0
  fi

  (cd "$theme_dir" && git pull --rebase --quiet)
  print_success "Powerlevel10k updated"
}

# Setup Powerlevel10k configuration
# Usage: setup_p10k_config <dotfiles_dir>
setup_p10k_config() {
  local dotfiles_dir="$1"
  local p10k_config="$HOME/.p10k.zsh"
  local p10k_template="$dotfiles_dir/zsh/.p10k.zsh"

  if [[ -f "$p10k_config" ]]; then
    print_debug "Powerlevel10k configuration already exists"
    return 0
  fi

  if [[ ! -f "$p10k_template" ]]; then
    print_debug "No Powerlevel10k template found"
    return 0
  fi

  print_info "Setting up Powerlevel10k configuration..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "copy Powerlevel10k config"
    return 0
  fi

  cp "$p10k_template" "$p10k_config"
  print_success "Powerlevel10k configuration created"
}

# ==============================================================================
# Shell Change
# ==============================================================================

# Set Zsh as the default shell
set_zsh_as_default() {
  local zsh_path

  # Get Zsh path
  zsh_path=$(which zsh 2>/dev/null)

  if [[ -z "$zsh_path" ]] || [[ ! -f "$zsh_path" ]]; then
    print_error "Could not find Zsh binary"
    return 1
  fi

  # Check if already default
  if [[ "$SHELL" == "$zsh_path" ]]; then
    print_success "Zsh is already the default shell"
    return 0
  fi

  print_info "Setting Zsh as default shell..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "set $zsh_path as default shell"
    return 0
  fi

  # Ensure Zsh is in /etc/shells
  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    print_info "Adding Zsh to /etc/shells..."
    if command -v sudo >/dev/null 2>&1; then
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
    fi
  fi

  # Check if Zsh is in /etc/shells
  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    print_warning "Zsh not in /etc/shells, cannot change default shell"
    print_info "Add it manually: echo $zsh_path | sudo tee -a /etc/shells"
    print_info "Then run: sudo chsh -s $zsh_path $USER"
    return 1
  fi

  # Change shell using sudo chsh (avoids password prompt issues)
  if sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    print_success "Default shell changed to Zsh"
    print_info "Log out and back in (or reboot) for the shell change to take effect"
    print_info "Or start Zsh now by typing: zsh"
    return 0
  else
    print_warning "Could not automatically change default shell"
    print_info "Run manually: sudo chsh -s $zsh_path $USER"
    print_info "Or start Zsh now by typing: zsh"
    return 1
  fi
}

# ==============================================================================
# Main Setup Function
# ==============================================================================

# Complete Zsh setup
# Usage: zsh_setup <dotfiles_dir> [--skip-shell-change]
zsh_setup() {
  local dotfiles_dir="$1"
  local skip_shell_change=""

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-shell-change) skip_shell_change="true" ;;
      *) ;;
    esac
    shift
  done

  print_section "Setting up Zsh"

  # Install Zsh
  install_zsh || return 1

  # Install Oh My Zsh
  install_oh_my_zsh || return 1

  # Install plugins
  install_zsh_plugins

  # Install Powerlevel10k
  install_powerlevel10k

  # Setup p10k config
  setup_p10k_config "$dotfiles_dir"

  # Set Zsh as default (unless skipped)
  if [[ -z "$skip_shell_change" ]]; then
    set_zsh_as_default
  fi

  print_success "Zsh setup complete"
}

# Update all Zsh components
# Usage: zsh_update
zsh_update() {
  print_section "Updating Zsh Components"

  update_oh_my_zsh
  update_zsh_plugins
  update_powerlevel10k

  print_success "Zsh components updated"
}

#!/usr/bin/env bash
# modules/vscode.sh - VSCode configuration and extensions
#
# Handles:
# - VSCode settings configuration (template-based)
# - Extension installation
# - Cross-platform support (macOS and Linux)
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/lib/backup.sh"
#   source "$DOTFILES_DIR/modules/vscode.sh"

# Prevent multiple sourcing
[[ -n "${_VSCODE_SH_LOADED:-}" ]] && return 0
readonly _VSCODE_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/vscode.sh" >&2
  exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

# List of recommended extensions
readonly VSCODE_EXTENSIONS=(
  "catppuccin.catppuccin-vsc"
  "streetsidesoftware.code-spell-checker"
  "fcrespo82.markdown-table-formatter"
)

# ==============================================================================
# VSCode Detection
# ==============================================================================

# Get VSCode configuration directory
# Outputs: path to VSCode User directory
get_vscode_config_dir() {
  local config_dir=""

  if [[ "$OS" == "macOS" ]]; then
    config_dir="$HOME/Library/Application Support/Code/User"
  elif [[ "$OS" == "Linux" ]]; then
    config_dir="$HOME/.config/Code/User"
  fi

  # Check for VSCode Insiders
  if [[ ! -d "$config_dir" ]]; then
    if [[ "$OS" == "macOS" ]]; then
      config_dir="$HOME/Library/Application Support/Code - Insiders/User"
    elif [[ "$OS" == "Linux" ]]; then
      config_dir="$HOME/.config/Code - Insiders/User"
    fi
  fi

  echo "$config_dir"
}

# Check if VSCode is installed
is_vscode_installed() {
  check_command code || check_command code-insiders
}

# Get VSCode command name
get_vscode_cmd() {
  if check_command code; then
    echo "code"
  elif check_command code-insiders; then
    echo "code-insiders"
  else
    echo ""
  fi
}

# ==============================================================================
# Settings Management
# ==============================================================================

# Setup VSCode settings from template
# Usage: setup_vscode_settings <dotfiles_dir> [--backup]
setup_vscode_settings() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local config_dir
  local settings_file
  local settings_local_file

  config_dir=$(get_vscode_config_dir)

  if [[ -z "$config_dir" ]]; then
    print_warning "Could not determine VSCode config directory"
    return 1
  fi

  settings_file="$config_dir/settings.json"
  settings_local_file="$config_dir/settings.local.json"

  # Check for template
  local template_file="$dotfiles_dir/vscode/settings.json.template"
  local legacy_file="$dotfiles_dir/vscode/settings.json"

  # Use template if available, fall back to legacy
  local source_file=""
  if [[ -f "$template_file" ]]; then
    source_file="$template_file"
  elif [[ -f "$legacy_file" ]]; then
    source_file="$legacy_file"
    print_debug "Using legacy settings.json (consider migrating to template)"
  else
    print_warning "No VSCode settings template found"
    return 1
  fi

  # Create config directory
  safe_mkdir "$config_dir"

  # Backup existing settings if requested
  if [[ "$should_backup" == "--backup" ]] && [[ -f "$settings_file" ]]; then
    backup_with_registry "$settings_file" || backup_if_exists "$settings_file" || true
  fi

  print_info "Setting up VSCode settings..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "copy VSCode settings from template"
    return 0
  fi

  # Copy settings from template
  if cp "$source_file" "$settings_file"; then
    print_success "VSCode settings installed"
  else
    print_error "Failed to install VSCode settings"
    return 1
  fi

  # Create local settings file if it doesn't exist
  local local_template="$dotfiles_dir/vscode/settings.local.json.template"
  if [[ ! -f "$settings_local_file" ]] && [[ -f "$local_template" ]]; then
    cp "$local_template" "$settings_local_file"
    print_info "Created $settings_local_file for personal settings"
  elif [[ ! -f "$settings_local_file" ]]; then
    # Create empty local settings
    echo "{}" > "$settings_local_file"
    print_info "Created empty $settings_local_file for personal settings"
  fi

  return 0
}

# ==============================================================================
# Extension Management
# ==============================================================================

# Check if an extension is installed
# Usage: is_extension_installed <extension_id>
is_extension_installed() {
  local ext_id="$1"
  local vscode_cmd

  vscode_cmd=$(get_vscode_cmd)
  [[ -z "$vscode_cmd" ]] && return 1

  "$vscode_cmd" --list-extensions 2>/dev/null | grep -qi "^${ext_id}$"
}

# Install a VSCode extension
# Usage: install_extension <extension_id>
install_extension() {
  local ext_id="$1"
  local vscode_cmd

  vscode_cmd=$(get_vscode_cmd)
  [[ -z "$vscode_cmd" ]] && return 1

  if is_extension_installed "$ext_id"; then
    print_debug "Extension already installed: $ext_id"
    return 0
  fi

  print_info "Installing extension: $ext_id"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "install extension: $ext_id"
    return 0
  fi

  if "$vscode_cmd" --install-extension "$ext_id" 2>/dev/null; then
    print_success "Installed: $ext_id"
    return 0
  else
    print_warning "Failed to install: $ext_id"
    return 1
  fi
}

# Install all recommended extensions
install_vscode_extensions() {
  local vscode_cmd

  vscode_cmd=$(get_vscode_cmd)

  if [[ -z "$vscode_cmd" ]]; then
    print_warning "VSCode command not found"
    return 1
  fi

  print_info "Installing VSCode extensions..."

  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    install_extension "$ext"
  done

  print_success "VSCode extensions installation complete"
}

# Update all installed extensions
update_vscode_extensions() {
  local vscode_cmd

  vscode_cmd=$(get_vscode_cmd)

  if [[ -z "$vscode_cmd" ]]; then
    return 1
  fi

  print_info "Updating VSCode extensions..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "update VSCode extensions"
    return 0
  fi

  # VSCode doesn't have a built-in update command
  # Extensions auto-update, so we just reinstall to force latest
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    "$vscode_cmd" --install-extension "$ext" --force 2>/dev/null || true
  done

  print_success "VSCode extensions updated"
}

# ==============================================================================
# Main Setup Function
# ==============================================================================

# Complete VSCode setup
# Usage: vscode_setup <dotfiles_dir> [--backup] [--skip-extensions]
vscode_setup() {
  local dotfiles_dir="$1"
  shift

  local backup_flag=""
  local skip_extensions=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backup) backup_flag="--backup" ;;
      --skip-extensions) skip_extensions="true" ;;
      *) ;;
    esac
    shift
  done

  if ! is_vscode_installed; then
    print_warning "VSCode not found. Skipping VSCode setup."
    return 0
  fi

  print_section "Setting up VSCode"

  # Check for config directory
  local config_dir
  config_dir=$(get_vscode_config_dir)

  if [[ -z "$config_dir" ]] || [[ ! -d "$(dirname "$config_dir")" ]]; then
    print_warning "VSCode user directory not found. Skipping config linking."
    return 0
  fi

  # Setup settings
  setup_vscode_settings "$dotfiles_dir" "$backup_flag"

  # Install extensions (unless skipped)
  if [[ -z "$skip_extensions" ]]; then
    install_vscode_extensions
  fi

  print_success "VSCode setup complete"
}

# ==============================================================================
# Verification
# ==============================================================================

# Verify VSCode setup
verify_vscode_setup() {
  local all_good=true

  if ! is_vscode_installed; then
    print_info "VSCode not installed"
    return 0
  fi

  print_info "Verifying VSCode setup..."

  # Check settings file
  local config_dir
  config_dir=$(get_vscode_config_dir)

  if [[ -f "$config_dir/settings.json" ]]; then
    print_success "VSCode settings.json is in place"
  else
    print_warning "VSCode settings.json is missing"
    all_good=false
  fi

  # Check extensions
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    if is_extension_installed "$ext"; then
      print_success "Extension installed: $ext"
    else
      print_warning "Extension missing: $ext"
      all_good=false
    fi
  done

  [[ "$all_good" == "true" ]]
}

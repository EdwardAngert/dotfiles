#!/usr/bin/env bash
# modules/terminal.sh - Terminal emulator configuration
#
# Handles terminal configuration for:
# - iTerm2 (macOS)
# - GNOME Terminal (Linux)
# - Konsole (KDE)
# - Alacritty (cross-platform)
#
# Usage:
#   source "$DOTFILES_DIR/lib/utils.sh"
#   source "$DOTFILES_DIR/lib/backup.sh"
#   source "$DOTFILES_DIR/modules/terminal.sh"

# Prevent multiple sourcing
[[ -n "${_TERMINAL_SH_LOADED:-}" ]] && return 0
readonly _TERMINAL_SH_LOADED=1

# Ensure required libraries are loaded
if [[ -z "${_UTILS_SH_LOADED:-}" ]]; then
  echo "ERROR: lib/utils.sh must be sourced before modules/terminal.sh" >&2
  exit 1
fi

# ==============================================================================
# iTerm2 (macOS)
# ==============================================================================

# Check if iTerm2 is installed
is_iterm_installed() {
  [[ -d "/Applications/iTerm.app" ]] || [[ -d "$HOME/Applications/iTerm.app" ]]
}

# Setup iTerm2 configuration
# Usage: setup_iterm <dotfiles_dir> [--backup]
setup_iterm() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"

  if ! is_iterm_installed; then
    print_debug "iTerm2 not found"
    return 0
  fi

  print_info "Configuring iTerm2..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "configure iTerm2"
    return 0
  fi

  # Backup existing preferences if requested
  if [[ "$should_backup" == "--backup" ]]; then
    local iterm_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    if [[ -f "$iterm_plist" ]]; then
      backup_with_registry "$iterm_plist" || backup_if_exists "$iterm_plist" || true
    fi
  fi

  # Ensure plist file exists and is valid
  local iterm_plist_source="$dotfiles_dir/iterm/com.googlecode.iterm2.plist"

  if [[ -f "$iterm_plist_source" ]]; then
    # Validate plist format
    if ! plutil -lint "$iterm_plist_source" >/dev/null 2>&1; then
      print_warning "iTerm2 plist file is malformed, creating a new properly formatted one..."
      defaults export com.googlecode.iterm2 "$iterm_plist_source" 2>/dev/null || true
    fi
  else
    # Export current preferences
    print_info "Creating iTerm2 plist file..."
    defaults export com.googlecode.iterm2 "$iterm_plist_source" 2>/dev/null || true
  fi

  # Configure iTerm2 to use our preferences
  print_info "Setting iTerm2 to load preferences from dotfiles..."
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$dotfiles_dir/iterm"

  # Create DynamicProfiles directory
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"

  print_success "iTerm2 configured!"
  print_info "Please restart iTerm2 for changes to take effect."
  print_info "Note: You may need to run 'killall cfprefsd' to force preference reload."

  return 0
}

# ==============================================================================
# Desktop Environment Detection (Linux)
# ==============================================================================

# Detect Linux desktop environment
# Outputs: desktop environment name (lowercase)
detect_desktop_environment() {
  local de=""

  # Try various environment variables
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    de="$XDG_CURRENT_DESKTOP"
  elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
    de="$DESKTOP_SESSION"
  elif [[ -n "${XDG_DATA_DIRS:-}" ]]; then
    de=$(echo "$XDG_DATA_DIRS" | grep -Eo 'gnome|kde|xfce|cinnamon|mate' | head -1)
  fi

  # Fallback: detect by running processes
  if [[ -z "$de" ]]; then
    if check_command gnome-shell || check_command gnome-session; then
      de="gnome"
    elif check_command plasmashell; then
      de="kde"
    elif check_command xfce4-session; then
      de="xfce"
    fi
  fi

  # Normalize to lowercase
  echo "${de,,}"
}

# ==============================================================================
# GNOME Terminal
# ==============================================================================

# Check if GNOME Terminal is available
has_gnome_terminal() {
  check_command gnome-terminal && check_command dconf
}

# Setup GNOME Terminal theme
# Usage: setup_gnome_terminal <dotfiles_dir>
setup_gnome_terminal() {
  local dotfiles_dir="$1"
  local theme_file="$dotfiles_dir/terminal/gnome-terminal-catppuccin.dconf"

  if ! has_gnome_terminal; then
    return 0
  fi

  if [[ ! -f "$theme_file" ]]; then
    print_warning "GNOME Terminal theme file not found"
    return 1
  fi

  print_info "Setting up GNOME Terminal theme..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_dry_run "load GNOME Terminal theme"
    return 0
  fi

  # Check for dconf
  if ! check_command dconf; then
    print_warning "dconf not found. Attempting to install..."

    case "$PACKAGE_MANAGER" in
      apt)
        sudo apt-get install -y dconf-cli
        ;;
      dnf)
        sudo dnf install -y dconf
        ;;
      pacman)
        sudo pacman -S --noconfirm dconf
        ;;
      *)
        print_error "Could not install dconf"
        return 1
        ;;
    esac
  fi

  if check_command dconf; then
    dconf load /org/gnome/terminal/legacy/profiles:/ < "$theme_file"
    print_success "GNOME Terminal theme installed"
  else
    print_error "dconf still not available"

    # Create fallback script
    local fallback_script="$HOME/.local/bin/apply-terminal-theme.sh"
    safe_mkdir "$(dirname "$fallback_script")"

    cat > "$fallback_script" << EOF
#!/bin/bash
# Run this script to apply the Catppuccin Mocha theme to GNOME Terminal
dconf load /org/gnome/terminal/legacy/profiles:/ < "$theme_file"
EOF
    chmod +x "$fallback_script"
    print_info "Created $fallback_script. Run it after installing dconf."
  fi

  return 0
}

# ==============================================================================
# Konsole (KDE)
# ==============================================================================

# Check if Konsole is available
has_konsole() {
  check_command konsole
}

# Setup Konsole theme
# Usage: setup_konsole <dotfiles_dir> [--backup]
setup_konsole() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local konsole_dir="$HOME/.local/share/konsole"
  local theme_file="$konsole_dir/Catppuccin-Mocha.colorscheme"
  local source_file="$dotfiles_dir/terminal/Catppuccin-Mocha.colorscheme"

  if ! has_konsole; then
    return 0
  fi

  if [[ ! -f "$source_file" ]]; then
    print_warning "Konsole theme file not found"
    return 1
  fi

  print_info "Setting up Konsole theme..."

  # Backup if requested
  if [[ "$should_backup" == "--backup" ]] && [[ -f "$theme_file" ]]; then
    backup_with_registry "$theme_file" || backup_if_exists "$theme_file" || true
  fi

  safe_mkdir "$konsole_dir"

  if safe_copy "$source_file" "$theme_file"; then
    print_success "Konsole theme installed"
    print_info "Please go to Konsole settings to apply it."
  else
    print_error "Failed to install Konsole theme"
    return 1
  fi

  return 0
}

# ==============================================================================
# Alacritty
# ==============================================================================

# Check if Alacritty is available
has_alacritty() {
  check_command alacritty
}

# Setup Alacritty configuration
# Usage: setup_alacritty <dotfiles_dir> [--backup]
setup_alacritty() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"
  local alacritty_dir="$HOME/.config/alacritty"
  local config_file="$alacritty_dir/alacritty.yml"
  local source_file="$dotfiles_dir/terminal/alacritty.yml"

  if ! has_alacritty; then
    return 0
  fi

  if [[ ! -f "$source_file" ]]; then
    print_debug "Alacritty config not found in dotfiles"
    return 0
  fi

  print_info "Setting up Alacritty..."

  # Backup if requested
  if [[ "$should_backup" == "--backup" ]]; then
    if [[ -f "$config_file" ]]; then
      backup_with_registry "$config_file" || backup_if_exists "$config_file" || true
    elif [[ -d "$alacritty_dir" ]]; then
      backup_with_registry "$alacritty_dir" || backup_if_exists "$alacritty_dir" || true
    fi
  fi

  safe_mkdir "$alacritty_dir"

  if safe_copy "$source_file" "$config_file"; then
    print_success "Alacritty configuration installed"
  else
    print_error "Failed to install Alacritty configuration"
    return 1
  fi

  return 0
}

# ==============================================================================
# Main Setup Function
# ==============================================================================

# Complete terminal setup
# Usage: terminal_setup <dotfiles_dir> [--backup]
terminal_setup() {
  local dotfiles_dir="$1"
  local should_backup="${2:-}"

  print_section "Setting up Terminal"

  if [[ "$OS" == "macOS" ]]; then
    # macOS: iTerm2 and Alacritty
    setup_iterm "$dotfiles_dir" "$should_backup"
    setup_alacritty "$dotfiles_dir" "$should_backup"
  elif [[ "$OS" == "Linux" ]]; then
    # Linux: Detect DE and setup appropriate terminal
    local de
    de=$(detect_desktop_environment)
    print_info "Detected desktop environment: ${de:-unknown}"

    case "$de" in
      *gnome*|*unity*|*ubuntu*)
        setup_gnome_terminal "$dotfiles_dir"
        ;;
      *kde*|*plasma*)
        setup_konsole "$dotfiles_dir" "$should_backup"
        ;;
      *)
        print_info "Unknown desktop environment, skipping DE-specific terminal setup"
        ;;
    esac

    # Alacritty is DE-independent
    setup_alacritty "$dotfiles_dir" "$should_backup"
  fi

  print_success "Terminal setup complete"
}

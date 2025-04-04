#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
  echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
  echo -e "${RED}ERROR:${NC} $1"
}

# Process command line arguments
UPDATE_MODE=false
if [[ "$1" == "--update" ]]; then
  UPDATE_MODE=true
  print_info "Running in update mode - will overwrite existing configurations"
fi

# Function to backup existing configuration
backup_if_exists() {
  if [ -f "$1" ] || [ -d "$1" ]; then
    BACKUP_PATH="$1.backup"
    print_info "Backing up existing $1 to $BACKUP_PATH"
    if mv "$1" "$BACKUP_PATH" 2>/dev/null; then
      print_success "Backup created: $BACKUP_PATH"
      return 0
    else
      print_error "Failed to create backup of $1. Check permissions."
      return 2
    fi
  fi
  return 1
}

# Determine backup behavior based on update mode
if [ "$UPDATE_MODE" = true ]; then
  SHOULD_BACKUP=false
  print_info "Update mode: Not backing up existing configurations"
else
  SHOULD_BACKUP=true
  print_info "Regular mode: Will backup existing configurations"
fi

# Directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect operating system
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  print_info "Detected Linux system. Setting up terminal themes..."
  
  # Check for desktop environment
  DE=""
  if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    DE=$XDG_CURRENT_DESKTOP
  elif [ -n "$DESKTOP_SESSION" ]; then
    DE=$DESKTOP_SESSION
  elif [ -n "$XDG_DATA_DIRS" ]; then
    DE=$(echo "$XDG_DATA_DIRS" | grep -Eo 'gnome|kde|xfce|cinnamon|mate')
  fi
  
  # Convert to lowercase if DE is not empty
  if [ -n "$DE" ]; then
    DE=$(echo "$DE" | tr '[:upper:]' '[:lower:]')
  else
    # Try to detect by looking for common executables
    if command -v gnome-shell &> /dev/null || command -v gnome-session &> /dev/null; then
      DE="gnome"
    elif command -v plasmashell &> /dev/null; then
      DE="kde"
    elif command -v xfce4-session &> /dev/null; then
      DE="xfce"
    else
      DE="unknown"
    fi
  fi
  
  print_info "Detected desktop environment: $DE"
  
  # Setup based on desktop environment
  if [[ "$DE" == *"gnome"* ]] || [[ "$DE" == *"unity"* ]] || [[ "$DE" == *"ubuntu"* ]]; then
    print_info "Setting up GNOME Terminal..."
    # Check for dconf, attempt to install if missing
    if ! command -v dconf &> /dev/null; then
      print_warning "dconf command not found. Attempting to install..."
      if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y dconf-cli
      elif command -v dnf &> /dev/null; then
        sudo dnf install -y dconf
      elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm dconf
      else
        print_error "Could not install dconf. Please install it manually."
      fi
    fi
    
    # Try using dconf again after potential installation
    if command -v dconf &> /dev/null; then
      dconf load /org/gnome/terminal/legacy/profiles:/ < "$SCRIPT_DIR/gnome-terminal-catppuccin.dconf"
      print_success "GNOME Terminal theme installed!"
    else
      print_error "dconf command not found. Unable to configure GNOME Terminal."
      
      # Fallback: create a simple script to apply the theme
      THEME_SCRIPT="$HOME/.local/bin/apply-terminal-theme.sh"
      mkdir -p "$(dirname "$THEME_SCRIPT")"
      echo "#!/bin/bash" > "$THEME_SCRIPT"
      echo "# Run this script to apply the Catppuccin Mocha theme to GNOME Terminal" >> "$THEME_SCRIPT"
      echo "dconf load /org/gnome/terminal/legacy/profiles:/ < $SCRIPT_DIR/gnome-terminal-catppuccin.dconf" >> "$THEME_SCRIPT"
      chmod +x "$THEME_SCRIPT"
      print_info "Created $THEME_SCRIPT. Run it after installing dconf."
    fi
  elif [[ "$DE" == *"kde"* ]] || [[ "$DE" == *"plasma"* ]]; then
    print_info "Setting up Konsole (KDE)..."
    KONSOLE_DIR="$HOME/.local/share/konsole"
    KONSOLE_THEME="$KONSOLE_DIR/Catppuccin-Mocha.colorscheme"
    
    # Backup existing config if option selected
    if [ "$SHOULD_BACKUP" = true ] && [ -f "$KONSOLE_THEME" ]; then
      backup_if_exists "$KONSOLE_THEME"
    fi
    
    mkdir -p "$KONSOLE_DIR"
    cp "$SCRIPT_DIR/Catppuccin-Mocha.colorscheme" "$KONSOLE_DIR/"
    print_success "Konsole theme installed! Please go to Konsole settings to apply it."
  else
    print_warning "Unknown or unsupported desktop environment: $DE"
    print_info "Installing only Alacritty configuration if available."
  fi
  
  # Setup Alacritty regardless of DE (if installed)
  if command -v alacritty &> /dev/null; then
    print_info "Setting up Alacritty..."
    ALACRITTY_DIR="$HOME/.config/alacritty"
    ALACRITTY_CONFIG="$ALACRITTY_DIR/alacritty.yml"
    
    # Backup existing config if option selected
    if [ "$SHOULD_BACKUP" = true ] && [ -f "$ALACRITTY_CONFIG" ]; then
      backup_if_exists "$ALACRITTY_CONFIG"
    elif [ "$SHOULD_BACKUP" = true ] && [ -d "$ALACRITTY_DIR" ]; then
      backup_if_exists "$ALACRITTY_DIR"
    fi
    
    mkdir -p "$ALACRITTY_DIR"
    cp "$SCRIPT_DIR/alacritty.yml" "$ALACRITTY_CONFIG"
    print_success "Alacritty configuration installed!"
  else
    print_info "Alacritty not found. Skipping Alacritty configuration."
  fi
  
elif [[ "$OSTYPE" == "darwin"* ]]; then
  print_info "Detected macOS. Setting up Alacritty if installed..."
  
  # Setup Alacritty if it exists on macOS
  if command -v alacritty &> /dev/null; then
    print_info "Setting up Alacritty..."
    ALACRITTY_DIR="$HOME/.config/alacritty"
    ALACRITTY_CONFIG="$ALACRITTY_DIR/alacritty.yml"
    
    # Backup existing config if option selected
    if [ "$SHOULD_BACKUP" = true ] && [ -f "$ALACRITTY_CONFIG" ]; then
      backup_if_exists "$ALACRITTY_CONFIG"
    elif [ "$SHOULD_BACKUP" = true ] && [ -d "$ALACRITTY_DIR" ]; then
      backup_if_exists "$ALACRITTY_DIR"
    fi
    
    mkdir -p "$ALACRITTY_DIR"
    cp "$SCRIPT_DIR/alacritty.yml" "$ALACRITTY_CONFIG"
    print_success "Alacritty configuration installed!"
  else
    print_info "Alacritty not found. Skipping Alacritty configuration."
  fi
  
else
  print_warning "Unsupported OS detected: $OSTYPE. Terminal configuration may not work properly."
fi

print_success "Terminal configuration completed!"
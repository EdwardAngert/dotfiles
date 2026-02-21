#!/usr/bin/env bash
# github/install-github-cli.sh - Install and configure GitHub CLI
#
# This script handles installation of the GitHub CLI across different
# platforms and includes authentication helpers.

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
source "$DOTFILES_DIR/modules/package-managers.sh"

# ==============================================================================
# Configuration
# ==============================================================================

AUTH_MODE=true
NON_INTERACTIVE=false
UPDATE_MODE=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --no-auth) AUTH_MODE=false ;;
    --non-interactive) NON_INTERACTIVE=true ;;
    --update) UPDATE_MODE=true ;;
    --dry-run) DRY_RUN=true ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --no-auth           Skip authentication steps"
      echo "  --non-interactive   Run without prompting (for automated scripts)"
      echo "  --update            Only update if already installed"
      echo "  --dry-run           Show what would be done without making changes"
      echo "  --help              Show this help message"
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
# Installation Functions
# ==============================================================================

# Install GitHub CLI from standalone binary
install_standalone_binary() {
  local temp_dir
  local gh_arch
  local version_tag

  # Create temporary directory
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  # Determine architecture
  case "$ARCH" in
    x86_64) gh_arch="amd64" ;;
    arm64) gh_arch="arm64" ;;
    arm32) gh_arch="arm" ;;
    *)
      print_error "Unsupported architecture: $ARCH"
      return 1
      ;;
  esac

  # Get latest version
  print_info "Determining latest GitHub CLI version..."
  version_tag=$(get_latest_github_release "cli/cli") || {
    print_error "Failed to determine latest version"
    return 1
  }

  local version_number="${version_tag#v}"
  local archive_name="gh_${version_number}_linux_${gh_arch}.tar.gz"
  local download_url="https://github.com/cli/cli/releases/download/${version_tag}/${archive_name}"

  # Download
  print_info "Downloading GitHub CLI ${version_tag} for ${gh_arch}..."
  if ! download_with_retry "$download_url" "$temp_dir/gh.tar.gz" "GitHub CLI"; then
    return 1
  fi

  # Extract
  print_info "Extracting archive..."
  if ! tar xzf "$temp_dir/gh.tar.gz" -C "$temp_dir"; then
    print_error "Extraction failed"
    return 1
  fi

  local gh_dir
  gh_dir=$(find "$temp_dir" -type d -name "gh_*" | head -n 1)
  if [[ -z "$gh_dir" ]]; then
    print_error "Could not find gh directory in archive"
    return 1
  fi

  # Install
  safe_mkdir "$HOME/.local/bin"
  cp "$gh_dir/bin/gh" "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/gh"

  # Update PATH
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
    update_shell_path
  fi

  return 0
}

update_shell_path() {
  local path_export='export PATH="$HOME/.local/bin:$PATH"'

  if [[ -f "$HOME/.zshrc.local" ]] && ! grep -q '.local/bin' "$HOME/.zshrc.local" 2>/dev/null; then
    echo "$path_export" >> "$HOME/.zshrc.local"
    print_info "Updated .zshrc.local with PATH"
  elif [[ -f "$HOME/.zshrc" ]] && ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo "$path_export" >> "$HOME/.zshrc"
    print_info "Updated .zshrc with PATH"
  elif [[ -f "$HOME/.bashrc" ]] && ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo "$path_export" >> "$HOME/.bashrc"
    print_info "Updated .bashrc with PATH"
  fi
}

# Install via package manager
install_gh_package_manager() {
  print_info "Installing GitHub CLI via package manager..."

  case "$PACKAGE_MANAGER" in
    brew)
      brew install gh
      ;;
    apt)
      # Import GitHub CLI GPG key and add repo
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null

      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

      sudo apt-get update
      sudo apt-get install -y gh
      ;;
    dnf)
      sudo dnf install -y 'dnf-command(config-manager)'
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo dnf install -y gh
      ;;
    pacman)
      sudo pacman -S --noconfirm github-cli
      ;;
    *)
      return 1
      ;;
  esac
}

install_gh() {
  print_info "Installing GitHub CLI..."

  # Try package manager first
  if [[ -n "$PACKAGE_MANAGER" ]]; then
    if install_gh_package_manager; then
      if check_command gh; then
        print_success "GitHub CLI installed successfully!"
        gh --version
        return 0
      fi
    fi
  fi

  # Fall back to standalone binary on Linux
  if [[ "$OS" == "Linux" ]]; then
    print_info "Trying standalone binary installation..."
    if install_standalone_binary; then
      if check_command gh; then
        print_success "GitHub CLI installed successfully!"
        gh --version
        return 0
      fi
    fi
  fi

  print_error "GitHub CLI installation failed"
  return 1
}

update_gh() {
  print_info "Updating GitHub CLI..."

  case "$PACKAGE_MANAGER" in
    brew)
      brew upgrade gh || true
      ;;
    apt)
      sudo apt-get update
      sudo apt-get install --only-upgrade -y gh
      ;;
    dnf)
      sudo dnf upgrade -y gh
      ;;
    pacman)
      sudo pacman -Syu --noconfirm github-cli
      ;;
    *)
      # Manual installation - reinstall
      if [[ -f "$HOME/.local/bin/gh" ]]; then
        install_standalone_binary
      fi
      ;;
  esac

  if check_command gh; then
    print_success "GitHub CLI updated!"
    gh --version
  fi
}

# ==============================================================================
# Authentication
# ==============================================================================

check_gh_auth() {
  check_command gh && gh auth status &>/dev/null
}

authenticate_gh() {
  if check_gh_auth; then
    print_success "GitHub CLI is already authenticated!"
    gh auth status
    return 0
  fi

  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      echo "$GITHUB_TOKEN" | gh auth login --with-token && {
        print_success "Authenticated with GitHub token"
        return 0
      }
    fi
    print_info "GitHub CLI installed but not authenticated (no GITHUB_TOKEN set)"
    print_info "To authenticate later, run: gh auth login"
    return 0
  fi

  # Interactive authentication
  if [[ -t 0 ]]; then
    print_info "Starting interactive GitHub authentication..."
    gh auth login || {
      print_warning "GitHub authentication was cancelled or failed"
      print_info "You can authenticate later by running: gh auth login"
    }
  else
    print_info "GitHub CLI installed but not authenticated (non-interactive terminal)"
    print_info "To authenticate later, run: gh auth login"
  fi

  return 0
}

# ==============================================================================
# Configuration
# ==============================================================================

configure_gh() {
  print_info "Configuring GitHub CLI..."

  # Set defaults (ignore errors if not authenticated)
  gh config set git_protocol ssh 2>/dev/null || true

  # Set editor
  if [[ -n "${EDITOR:-}" ]]; then
    gh config set editor "$EDITOR" 2>/dev/null || true
  elif check_command nvim; then
    gh config set editor nvim 2>/dev/null || true
  elif check_command vim; then
    gh config set editor vim 2>/dev/null || true
  fi

  # Setup shell completion
  local shell_type
  shell_type=$(basename "${SHELL:-bash}")
  local completion_line='eval "$(gh completion -s '"$shell_type"')"'

  case "$shell_type" in
    zsh)
      if ! grep -q "gh completion" "$HOME/.zshrc" 2>/dev/null && \
         ! grep -q "gh completion" "$HOME/.zshrc.local" 2>/dev/null; then
        if [[ -f "$HOME/.zshrc.local" ]]; then
          echo -e "\n# GitHub CLI completion\n$completion_line" >> "$HOME/.zshrc.local"
        else
          echo -e "\n# GitHub CLI completion\n$completion_line" >> "$HOME/.zshrc"
        fi
      fi
      ;;
    bash)
      if ! grep -q "gh completion" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "\n# GitHub CLI completion\n$completion_line" >> "$HOME/.bashrc"
      fi
      ;;
  esac

  print_success "GitHub CLI configured!"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  # Dry-run mode - just show what would happen
  if [[ "$DRY_RUN" == "true" ]]; then
    if check_command gh; then
      print_success "GitHub CLI is already installed!"
      gh --version
      if [[ "$UPDATE_MODE" == "true" ]]; then
        print_dry_run "update GitHub CLI"
      fi
    else
      print_dry_run "install GitHub CLI"
    fi
    print_dry_run "configure GitHub CLI"
    return 0
  fi

  if check_command gh; then
    if [[ "$UPDATE_MODE" == "true" ]]; then
      update_gh
    else
      print_success "GitHub CLI is already installed!"
      gh --version

      if [[ "$AUTH_MODE" == "true" ]] && ! check_gh_auth; then
        authenticate_gh
      fi
    fi
  else
    if [[ "$UPDATE_MODE" == "true" ]]; then
      print_info "GitHub CLI not installed. Skipping update."
      return 0
    fi

    if ! install_gh; then
      print_warning "Failed to install GitHub CLI. Continuing without it."
      return 0
    fi

    if [[ "$AUTH_MODE" == "true" ]]; then
      authenticate_gh
    fi
  fi

  # Configure if installed and functional
  if check_command gh && gh --version &>/dev/null; then
    configure_gh
    print_success "GitHub CLI setup complete!"

    if check_gh_auth; then
      print_info "GitHub CLI is authenticated"
    else
      print_info "GitHub CLI is not authenticated. Run 'gh auth login' when ready."
    fi
  fi
}

main

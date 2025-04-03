# Dotfiles

Personal configuration files for VSCode, Neovim, and Zsh. These dotfiles are designed to work on both macOS and Linux systems and will automatically install required dependencies.

## Contents

- `vscode/`: VS Code configuration
- `nvim/`: Neovim configuration
- `zsh/`: Zsh configuration
- `iterm/`: iTerm2 configuration (macOS)
- `terminal/`: Terminal configurations for Linux
- `fonts/`: Programming fonts installation scripts
- `install.sh`: Installation script that installs dependencies and creates symlinks

## Features

- 🚀 **Automatic installation** of all required dependencies
- 🔄 **Cross-platform** support for macOS and major Linux distributions
- 🧩 **Oh My Zsh** with useful plugins pre-configured
- 🎨 **Neovim** with modern plugins and Catppuccin Mocha theme
- 🧰 **VSCode** settings with Catppuccin Mocha theme
- 🖥️ **Terminal configurations** for iTerm2 (macOS) and Linux terminals
- 🔤 **JetBrains Mono font** installation for better readability
- 🌈 **Consistent theming** across all tools with Catppuccin

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/EdwardAngert/dotfiles.git
   cd dotfiles
   ```

2. Make the installation script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the installation script:
   ```bash
   ./install.sh
   ```

### Advanced Installation Options

The installation script supports various options to customize the installation:

```bash
./install.sh --help
```

Available options:
- `--skip-fonts`: Skip font installation
- `--skip-neovim`: Skip Neovim configuration
- `--skip-zsh`: Skip Zsh configuration
- `--skip-vscode`: Skip VSCode configuration
- `--skip-terminal`: Skip terminal configuration

For example, to install everything except fonts:
```bash
./install.sh --skip-fonts
```

The script will:

- Install package managers if needed (Homebrew, apt, dnf, pacman)
- Install and configure Zsh, Oh My Zsh, and plugins
- Install Neovim and vim-plug
- Automatically back up any existing configurations (with .backup suffix)
- Create all necessary symlinks
- Set Zsh as the default shell

## What Gets Installed

The installation script automatically installs:

- **Zsh** - Modern shell with advanced features
- **Oh My Zsh** - Framework for managing Zsh configuration
- **Zsh plugins** - autosuggestions, syntax-highlighting, and more
- **Neovim** - Improved Vim editor
- **vim-plug** - Plugin manager for Neovim
- **JetBrains Mono** - Programming font with ligatures
- **VSCode Extensions** - Catppuccin theme for consistent styling
- **Terminal Configurations**:
  - iTerm2 Configuration (macOS)
  - GNOME Terminal, Konsole and Alacritty (Linux)

## Customization

### VSCode

Edit `vscode/settings.json` to customize your VSCode settings.

### Neovim

Edit `nvim/init.vim` to customize your Neovim configuration.

### Zsh

Edit `zsh/.zshrc` to customize your Zsh configuration.

## Manual Installation

If you prefer to install dependencies manually:

### Oh My Zsh
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Oh My Zsh Plugins
```bash
# Install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

### vim-plug
```bash
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```
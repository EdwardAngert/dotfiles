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
- 🔁 **Update system** for keeping dotfiles current with `--update` and `--pull` options
- ⏱️ **Automated updates** via cron job to keep everything up-to-date
- 🛠️ **Fallback configurations** for environments with restricted dependencies
- 🐙 **GitHub CLI** installation and configuration for streamlined Git workflows

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git
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
- `--update`: Update mode - skip dependency installation, only update configs
- `--pull`: Pull latest changes from git repository before installing
- `--setup-auto-update`: Configure automatic weekly updates via cron

For example, to install everything except fonts:
```bash
./install.sh --skip-fonts
```

To update an existing installation:
```bash
./install.sh --update
```

To pull the latest changes and update:
```bash
./install.sh --pull --update
```

To set up automated weekly updates:
```bash
./install.sh --setup-auto-update
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
- **GitHub CLI** - Command-line tool for GitHub workflows
- **Terminal Configurations**:
  - iTerm2 Configuration (macOS)
  - GNOME Terminal, Konsole and Alacritty (Linux)

## Customization

### VSCode

Edit `vscode/settings.json` to customize your VSCode settings.

### Neovim

Edit `nvim/init.vim` to customize your Neovim configuration.

During installation, you can choose from several Neovim configuration templates:
- **Default**: Basic template with minimal customization
- **Catppuccin**: Configured with the Catppuccin color theme and additional plugins
- **Monokai**: Configured with the Monokai color theme and additional plugins

These templates are copied to `~/.config/nvim/personal.vim` and loaded automatically by the main configuration.

### Zsh

Edit `zsh/.zshrc` to customize your Zsh configuration.

## Updating

There are several ways to update your dotfiles installation:

### Updating on an Existing Machine

If you already have the dependencies installed and just want to update your configurations:

```bash
./install.sh --update
```

This will skip dependency installation and only update your configurations.

### Pulling Latest Changes

To get the latest changes from the repository and apply them:

```bash
./install.sh --pull --update
```

This will pull the latest changes from the git repository and then update your configurations.

### Automated Updates

You can set up a weekly cron job to automatically update your dotfiles:

```bash
./install.sh --setup-auto-update
```

This will create a weekly cron job that runs every Sunday at noon to pull the latest changes and update your configurations. A script will be created at `~/.local/bin/update-dotfiles.sh` that you can also run manually anytime.

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
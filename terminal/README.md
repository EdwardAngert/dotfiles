# Terminal Configuration

This directory contains terminal configuration files for Linux and macOS systems.

## Contents

- `alacritty.yml`: Configuration for the Alacritty terminal emulator (cross-platform)
- `gnome-terminal-catppuccin.dconf`: GNOME Terminal profile with Catppuccin Mocha theme
- `Catppuccin-Mocha.colorscheme`: KDE Konsole color scheme
- `install-terminal-themes.sh`: Script to install terminal themes

## Installation

### Automatic (via install.sh)

The main `install.sh` script in the parent directory will automatically set up terminal configurations if they're installed.

### Manual Terminal Theme Installation

You can manually install the terminal themes by running:

```bash
./install-terminal-themes.sh
```

This script will detect your desktop environment and install the appropriate theme.

## Supported Terminals

- **GNOME Terminal** (Ubuntu, Pop!_OS, Fedora Workstation, etc.)
- **Konsole** (KDE Plasma)
- **Alacritty** (Cross-platform)
- **iTerm2** (macOS - configured separately in the `iterm` directory)

## Features

- Catppuccin Mocha color scheme for consistent theming with VSCode and Neovim
- JetBrains Mono font (12pt) for clear readability and programming ligatures
- Sensible terminal settings for developer productivity
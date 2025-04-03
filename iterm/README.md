# iTerm2 Configuration

This directory contains configuration files for iTerm2.

## Contents

- `Catppuccin Mocha.itermcolors`: Color scheme file for the Catppuccin Mocha theme
- `com.googlecode.iterm2.plist`: iTerm2 preferences file

## Installation

### Automatic (via install.sh)

The main `install.sh` script in the parent directory will automatically set up iTerm2 if it's installed.

### Manual Color Scheme Installation

1. Open iTerm2
2. Go to `Preferences > Profiles > Colors`
3. Click on `Color Presets...` at the bottom right
4. Select `Import...`
5. Navigate to this directory and select `Catppuccin Mocha.itermcolors`
6. Click on `Color Presets...` again and select `Catppuccin Mocha`

### Manual Preferences

If you want to use the included preferences file:

1. Open iTerm2
2. Go to `Preferences > General`
3. Check `Load preferences from a custom folder or URL`
4. Click `Browse` and navigate to this directory
5. Select the `com.googlecode.iterm2.plist` file
6. Restart iTerm2

## Features

- Catppuccin Mocha color scheme for consistent theming with VSCode and Neovim
- JetBrains Mono font (12pt) for clear readability and programming ligatures
- Sensible terminal settings for developer productivity
- Mouse reporting and scrolling enabled
- Visual bell (instead of audio)
- Unlimited scrollback
# Dotfiles

Personal configuration files for development environments. These dotfiles provide a consistent, productive setup across macOS and Linux systems with automatic dependency installation.

## Requirements

| Requirement | Version | Purpose |
|-------------|---------|---------|
| bash | 4.0+ | Installation scripts |
| git | 2.0+ | Version control, plugin installation |
| curl | any | Downloading files |
| Neovim | 0.9.0+ | Lua plugins, Treesitter (auto-installed) |
| Node.js | 16.0+ | Neovim CoC completion (auto-installed) |

## Platform Support

| Platform | Package Manager | Status |
|----------|-----------------|--------|
| macOS | Homebrew | Full support |
| Ubuntu/Debian | apt | Full support |
| Fedora/RHEL | dnf | Full support |
| Arch Linux | pacman | Full support |
| Alpine Linux | apk | Partial support |
| Other Linux | Homebrew | Fallback |

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# Run the installer
./install.sh
```

That's it! The installer will:
- Detect your OS and package manager
- Install all required dependencies
- Set up Zsh with Oh My Zsh and Powerlevel10k
- Configure Neovim with plugins
- Install fonts and terminal themes
- Create symlinks for all configurations

## Architecture

```
dotfiles/
├── install.sh              # Main orchestrator (~200 lines)
├── lib/                    # Shared libraries
│   ├── utils.sh            # Colors, printing, file operations
│   ├── network.sh          # Downloads with retry, checksums
│   └── backup.sh           # Backup registry for rollback
├── modules/                # Feature modules
│   ├── package-managers.sh # Homebrew, apt, dnf, pacman, apk
│   ├── dependencies.sh     # git, curl, build tools
│   ├── nodejs.sh           # Node.js via package manager or NVM
│   ├── neovim.sh           # Neovim binary + vim-plug
│   ├── zsh.sh              # Zsh, Oh My Zsh, plugins, p10k
│   ├── link-configs.sh     # Symlink management
│   ├── vscode.sh           # VSCode settings + extensions
│   └── terminal.sh         # iTerm2, GNOME Terminal, Konsole
├── nvim/                   # Neovim configuration
├── zsh/                    # Zsh configuration
├── vscode/                 # VSCode settings (template-based)
├── fonts/                  # Font installation
├── terminal/               # Terminal themes
├── iterm/                  # iTerm2 configuration (macOS)
├── github/                 # GitHub CLI setup
└── tests/                  # Test infrastructure
```

## Installation Options

| Flag | Description |
|------|-------------|
| `--help` | Show help message |
| `--skip-fonts` | Skip font installation |
| `--skip-neovim` | Skip Neovim configuration |
| `--skip-zsh` | Skip Zsh configuration |
| `--skip-vscode` | Skip VSCode configuration |
| `--skip-terminal` | Skip terminal configuration |
| `--update` | Update mode - skip dependency installation |
| `--pull` | Pull latest changes before installing |
| `--dry-run` | Preview changes without making them |
| `--rollback` | Rollback to previous configuration |
| `--setup-auto-update` | Configure weekly automatic updates |

### Examples

```bash
# Fresh installation
./install.sh

# Update existing installation
./install.sh --update

# Pull latest and update
./install.sh --pull --update

# Preview what would change
./install.sh --dry-run

# Skip specific components
./install.sh --skip-fonts --skip-vscode

# Rollback last changes
./install.sh --rollback

# Set up automatic weekly updates
./install.sh --setup-auto-update
```

## What Gets Installed

### Shell
- **Zsh** - Modern shell with advanced features
- **Oh My Zsh** - Zsh configuration framework
- **Powerlevel10k** - Fast, customizable prompt theme
- **zsh-autosuggestions** - Fish-like autosuggestions
- **zsh-syntax-highlighting** - Syntax highlighting for commands

### Editor
- **Neovim 0.9+** - Modern Vim with Lua support
- **vim-plug** - Plugin manager
- **CoC.nvim** - Intellisense engine (requires Node.js)
- **Telescope** - Fuzzy finder
- **Treesitter** - Better syntax highlighting

### Tools
- **tig** - Text-mode interface for Git
- **ripgrep** - Fast search tool
- **fd** - Fast file finder
- **fzf** - Fuzzy finder
- **GitHub CLI** - GitHub from the command line

### Fonts & Themes
- **JetBrains Mono Nerd Font** - Programming font with icons
- **Catppuccin Mocha** - Consistent theme across all tools

## Uninstall / Rollback

### Rollback Recent Changes

The installer creates backups in `~/.dotfiles-backups/`. To rollback:

```bash
./install.sh --rollback
```

This will:
1. List available backup sessions
2. Show what will be restored
3. Ask for confirmation
4. Restore previous configurations

### Manual Uninstall

To remove dotfiles configurations:

```bash
# Remove symlinks
rm -f ~/.zshrc ~/.config/nvim/init.vim

# Restore backups (if any)
ls ~/.dotfiles-backups/

# Remove Oh My Zsh
rm -rf ~/.oh-my-zsh

# Change shell back to bash
chsh -s /bin/bash
```

## Customization

### Local Configuration Files

These files are for machine-specific settings and are not tracked in git:

| File | Purpose |
|------|---------|
| `~/.zshrc.local` | Local Zsh customizations |
| `~/.config/nvim/personal.vim` | Personal Neovim settings |
| `~/.gitconfig.local` | Git user identity |

### Neovim Templates

During installation, one of these templates is automatically selected based on your system:

- **personal.catppuccin.vim** - Full setup with Catppuccin theme (default)
- **personal.monokai.vim** - Monokai theme variant
- **personal.nococ.vim** - For systems without Node.js
- **personal.nolua.vim** - For older Neovim without Lua support

### VSCode

VSCode settings use a template system:
- `vscode/settings.json.template` - Base settings (tracked)
- `vscode/settings.local.json.template` - Personal settings template

Personal settings (SSH hosts, etc.) should go in `settings.local.json`.

## Updating

### Manual Update

```bash
cd /path/to/dotfiles
./install.sh --pull --update
```

### Automatic Updates

Set up weekly automatic updates:

```bash
./install.sh --setup-auto-update
```

This creates a cron job that runs every Sunday at noon.

## Troubleshooting

### Fonts not displaying correctly

1. Ensure JetBrains Mono Nerd Font is installed:
   ```bash
   ./fonts/install-fonts.sh
   ```
2. Set your terminal font to "JetBrainsMono Nerd Font"
3. Restart your terminal

### Neovim plugins not working

1. Check Node.js is installed: `node --version`
2. Reinstall plugins:
   ```bash
   nvim +PlugInstall +qall
   ```
3. Check for errors: `nvim +checkhealth`

### Zsh not default shell

```bash
# Add zsh to allowed shells
echo $(which zsh) | sudo tee -a /etc/shells

# Change default shell
chsh -s $(which zsh)

# Log out and back in
```

### Dry run shows unexpected changes

Use `--dry-run` to preview:
```bash
./install.sh --dry-run
```

This shows what would change without making any modifications.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run shellcheck: `./tests/run_tests.sh`
5. Submit a pull request

## License

MIT License - feel free to use and modify as you wish.

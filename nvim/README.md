# Neovim Configuration

A modern, feature-rich Neovim configuration with sensible defaults and customization options.

## Features

- Modern look with Catppuccin theme
- Git integration with fugitive and gitgutter
- Fuzzy finding with Telescope
- Auto-completion with CoC
- Enhanced syntax highlighting with Treesitter
- Markdown support
- Lightweight and fast with smart defaults

## Installation

The configuration will be automatically set up when you run the main dotfiles installation script:

```bash
cd /path/to/dotfiles
./install.sh
```

### Dependencies

- Neovim 0.5.0 or newer
- Node.js (for CoC completion)
- Git (for plugin installation)
- A terminal that supports true colors for best experience

### Manual Installation

If you want to install only the Neovim configuration:

1. Install vim-plug if not already installed:
```bash
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

2. Copy `init.vim` to your Neovim config directory:
```bash
mkdir -p ~/.config/nvim
cp nvim/init.vim ~/.config/nvim/
```

3. Open Neovim and run `:PlugInstall` to install plugins

## Customization

You can customize the configuration by creating a `personal.vim` file in your `~/.config/nvim/` directory.
This file will be loaded before the main configuration, allowing you to override settings.

Example `personal.vim`:

```vim
" Override theme
let g:preferred_colorscheme = 'monokai'

" Add your own plugins
let g:additional_plugins = ['your/plugin', 'another/plugin']

" Custom keybindings
nnoremap <leader>x :YourCommand<CR>
```

## Key Mappings

### General Mappings

- `<Space>` - Leader key

### Telescope

- `<leader>ff` - Find files
- `<leader>fg` - Live grep (search in all files)
- `<leader>fb` - Browse open buffers
- `<leader>fh` - Search help tags

### Text Editing

- `gcc` - Comment/uncomment current line (vim-commentary)
- `gc` - Comment/uncomment selection (in visual mode)
- `cs"'` - Change surrounding quotes from " to ' (vim-surround)
- `ds"` - Delete surrounding quotes (vim-surround)
- `ysiw]` - Surround word with [] (vim-surround)

### Git (Fugitive)

- `:Git` - Main command interface
- `:Git blame` - Show git blame
- `:Git commit` - Commit changes
- `:Git push` - Push to remote

### Tabular

- `:Tabularize /=` - Align text around = signs

### CoC

- `<C-Space>` - Trigger completion
- `[g` and `]g` - Navigate diagnostics
- `gd` - Go to definition
- `gy` - Go to type definition
- `gi` - Go to implementation
- `gr` - Go to references

## Plugin List

| Plugin | Purpose |
|--------|---------|
| neoclide/coc.nvim | Code completion and language server protocol support |
| nvim-treesitter/nvim-treesitter | Advanced syntax highlighting |
| nvim-telescope/telescope.nvim | Fuzzy finder with previews |
| catppuccin/nvim | Modern, soft color scheme |
| tpope/vim-fugitive | Git integration from within vim |
| airblade/vim-gitgutter | Shows git diff markers in the gutter |
| itchyny/lightline.vim | Lightweight status line with branch info |
| Yggdroot/indentLine | Shows vertical lines for indentation |
| tpope/vim-commentary | Easy commenting of code |
| tpope/vim-surround | Easily change surrounding characters |
| godlygeek/tabular | Text alignment tool |
| plasticboy/vim-markdown | Enhanced markdown support |
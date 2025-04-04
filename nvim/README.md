# Neovim Configuration

A modern, feature-rich Neovim configuration with sensible defaults and customization options.

## Features

- Modern look with Catppuccin theme
- Git integration with fugitive and gitgutter
- Fuzzy finding with Telescope and FZF integration
- Auto-completion with CoC (including support for JSON, YAML, TOML)
- Enhanced syntax highlighting with Treesitter
- Markdown support with table formatting and improved writing experience
- Session management for seamless workflow across git repositories
- Auto-formatting for config files
- Auto-save when focus is lost
- Spell checking for markdown files
- Easy text alignment tools
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
- `<leader>fr` - Recently opened files (MRU)
- `<leader>fc` - Find text in current file

### Text Editing

- `gcc` - Comment/uncomment current line (vim-commentary)
- `gc` - Comment/uncomment selection (in visual mode)
- `cs"'` - Change surrounding quotes from " to ' (vim-surround)
- `ds"` - Delete surrounding quotes (vim-surround)
- `ysiw]` - Surround word with [] (vim-surround)
- `ga` - Start Easy Align (visual mode or with motion)

### Git (Fugitive)

- `<leader>gs` - Git status
- `<leader>gc` - Git commit
- `<leader>gp` - Git push
- `<leader>gl` - Git pull
- `<leader>gd` - Git diff
- `<leader>gb` - Git blame

### Markdown

- `<leader>tt` - Toggle table mode
- `<leader>tm` - Convert selected text to table (visual mode)
- `<leader>tr` - Realign table
- Spell checking enabled by default

### Session Management

- `<leader>ss` - Start/pause session recording
- `<leader>sl` - Load session

### Tabular & Alignment

- `:Tabularize /=` - Align text around = signs
- `vipga=` - In visual mode, select paragraph and align around =

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
| nvim-telescope/telescope-fzf-native.nvim | FZF integration for faster searching |
| catppuccin/nvim | Modern, soft color scheme |
| tpope/vim-fugitive | Git integration from within vim |
| airblade/vim-gitgutter | Shows git diff markers in the gutter |
| itchyny/lightline.vim | Lightweight status line with branch info |
| Yggdroot/indentLine | Shows vertical lines for indentation |
| tpope/vim-commentary | Easy commenting of code |
| tpope/vim-surround | Easily change surrounding characters |
| godlygeek/tabular | Text alignment tool |
| junegunn/vim-easy-align | Align text around characters with interactive interface |
| plasticboy/vim-markdown | Enhanced markdown support |
| dhruvasagar/vim-table-mode | Easy table creation and formatting in markdown |
| reedes/vim-pencil | Better writing experience with soft wrapping |
| tpope/vim-obsession | Session management for persistent workflow |
| sbdchd/neoformat | Auto-formatting for many languages and file types |
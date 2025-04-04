" Load personal settings first if they exist
if filereadable(expand('~/.config/nvim/personal.vim'))
  source ~/.config/nvim/personal.vim
endif

" Basic Settings (can be overridden by personal.vim)
if !exists('g:basic_settings_loaded')
  set number          " Simple line numbers (no relative)
  set expandtab       " Tabs are spaces
  set tabstop=2       " Number of spaces per tab
  set shiftwidth=2    " Spaces for autoindent
  set softtabstop=2   " Spaces per tab when editing
  set autoindent      " Auto indent based on previous line
  set smartindent     " Smart autoindent for C-like programs
  set smarttab        " Smart handling of tab at start of line
  set mouse=a         " Enable mouse support
  set clipboard=unnamed " Use system clipboard
  set wildmenu        " Show autocompletion menu
  set hidden          " Allow unsaved buffers to be hidden
  
  " Search settings
  set ignorecase      " Case insensitive search...
  set smartcase       " ...unless search contains uppercase
  set incsearch       " Incremental search
  set hlsearch        " Highlight search results
  
  " UI settings
  set cursorline      " Highlight current line
  set colorcolumn=80,120 " Show guides at 80 and 120 chars
  if exists('&signcolumn')
    set signcolumn=yes " Always show sign column for git markers etc.
  endif
  set scrolloff=8     " Keep cursor 8 lines from edge when scrolling
  
  " File settings
  set encoding=utf-8  " UTF-8 encoding
  set nobackup        " No backup files
  set nowritebackup   " No backup while editing
  set noswapfile      " No swap files
  
  " Colors
  if has('termguicolors')
    set termguicolors " Use true colors in terminal
  endif
  set updatetime=100  " Faster updates for gitgutter etc.
  
  let g:basic_settings_loaded = 1
endif

" Key mappings
let mapleader = " " " Space as leader key

" Plugin management with vim-plug (only if installed)
if filereadable(expand('~/.vim/autoload/plug.vim')) || filereadable(expand('~/.local/share/nvim/site/autoload/plug.vim'))
  " Plugin management with vim-plug
  call plug#begin('~/.vim/plugged')

  " Allow custom plugins to be defined in personal.vim
  if exists('g:custom_plugins_loaded') && g:custom_plugins_loaded == 1
    " Skip default plugins as they were defined in personal.vim
  else
    " Core plugins
    " Code completion and assistance
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    let g:coc_disable_startup_warning = 1
    
    " Syntax and highlighting
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    
    " Fuzzy finder
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    
    " Theme
    Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
    
    " Git integration
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    
    " UI enhancements
    Plug 'itchyny/lightline.vim'
    Plug 'Yggdroot/indentLine'
    
    " Text editing helpers
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-surround'
    Plug 'godlygeek/tabular'
    
    " Markdown support
    Plug 'plasticboy/vim-markdown'
    let g:vim_markdown_frontmatter = 1 " YAML syntax highlighting
    
    " Load additional plugins if specified
    if exists('g:additional_plugins') && type(g:additional_plugins) == 3  " Check if it's a list
      for plugin in g:additional_plugins
        execute 'Plug ' . "'" . plugin . "'"
      endfor
    endif
  endif

  call plug#end()

  " Theme configuration
  " Configure Catppuccin flavor
  let g:catppuccin_flavour = get(g:, 'catppuccin_flavour', 'mocha')  " Allow override
  let g:catppuccin_transparent = get(g:, 'catppuccin_transparent', 0)  " Allow override

  lua << EOF
  -- Check if the 'catppuccin' module exists before requiring it
  local has_catppuccin, catppuccin = pcall(require, "catppuccin")
  if has_catppuccin then
    catppuccin.setup({
      flavour = vim.g.catppuccin_flavour or "mocha", -- latte, frappe, macchiato, mocha
      background = { 
        light = "latte",
        dark = "mocha",
      },
      transparent_background = vim.g.catppuccin_transparent == 1,
      term_colors = true,
      integrations = {
        coc_nvim = true,
        nvimtree = true,
        telescope = true,
        treesitter = true,
        semantic_tokens = true,
        gitgutter = true,
      },
    })
  end
EOF
  
  " Apply theme - allow override from environment or personal.vim
  let g:preferred_colorscheme = get(g:, 'preferred_colorscheme', 'catppuccin')
  if g:preferred_colorscheme == 'catppuccin'
    silent! colorscheme catppuccin
  else
    silent! execute 'colorscheme ' . g:preferred_colorscheme
  endif
  
  " Configure lightline to use Catppuccin and show branch
  let g:lightline = {
      \ 'colorscheme': 'catppuccin',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'FugitiveHead'
      \ },
      \ }

  " Indent Line settings
  let g:indentLine_char = '│'
  let g:indentLine_enabled = 1

  " Telescope mappings
  nnoremap <leader>ff <cmd>Telescope find_files<cr>
  nnoremap <leader>fg <cmd>Telescope live_grep<cr>
  nnoremap <leader>fb <cmd>Telescope buffers<cr>
  nnoremap <leader>fh <cmd>Telescope help_tags<cr>
else
  " Fallback theme if no plugins
  if !has('gui_running')
    set t_Co=256
  endif
  silent! colorscheme default
  
  " Basic file finder mapping without telescope
  nnoremap <leader>ff :find *
  nnoremap <leader>fg :grep<space>
  nnoremap <leader>fb :ls<cr>:b<space>
endif

" Install vim-plug message
if !filereadable(expand('~/.vim/autoload/plug.vim')) && !filereadable(expand('~/.local/share/nvim/site/autoload/plug.vim'))
  echo "vim-plug not installed. Install with:"
  echo "curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
endif
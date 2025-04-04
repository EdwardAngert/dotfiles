" Load personal settings first if they exist
if filereadable(expand('~/.config/nvim/personal.vim'))
  source ~/.config/nvim/personal.vim
endif

" Basic Settings (can be overridden by personal.vim)
if !exists('g:basic_settings_loaded')
  set number
  set relativenumber
  set expandtab
  set tabstop=2
  set shiftwidth=2
  set softtabstop=2
  set autoindent
  set smartindent
  set smarttab
  set mouse=a
  set clipboard=unnamed
  set ignorecase
  set smartcase
  set incsearch
  set hlsearch
  set colorcolumn=80,120
  set cursorline
  " Only use termguicolors if supported
  if has('termguicolors')
    set termguicolors
  endif
  set scrolloff=8
  " Only use signcolumn if supported
  if exists('&signcolumn')
    set signcolumn=yes
  endif
  set updatetime=100
  set encoding=utf-8
  set nobackup
  set nowritebackup
  set noswapfile
  let g:basic_settings_loaded = 1
endif

" Key mappings
let mapleader = " "

" Plugin management with vim-plug (only if installed)
if filereadable(expand('~/.vim/autoload/plug.vim')) || filereadable(expand('~/.local/share/nvim/site/autoload/plug.vim'))
  " Plugin management with vim-plug
  call plug#begin('~/.vim/plugged')

  " Allow custom plugins to be defined in personal.vim
  if exists('g:custom_plugins_loaded') && g:custom_plugins_loaded == 1
    " Skip default plugins as they were defined in personal.vim
  else
    " Core plugins
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    let g:coc_disable_startup_warning = 1
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
    Plug 'jiangmiao/auto-pairs'
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-surround'
    Plug 'airblade/vim-gitgutter'
    Plug 'itchyny/lightline.vim'
    
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
  
  " Configure lightline to use Catppuccin
  let g:lightline = {'colorscheme': 'catppuccin'}

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
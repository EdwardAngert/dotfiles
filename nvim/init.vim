" Basic Settings
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

" Key mappings
let mapleader = " "

" Plugin management with vim-plug (only if installed)
if filereadable(expand('~/.vim/autoload/plug.vim')) || filereadable(expand('~/.local/share/nvim/site/autoload/plug.vim'))
  " Plugin management with vim-plug
  call plug#begin('~/.vim/plugged')

  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
  Plug 'jiangmiao/auto-pairs'
  Plug 'tpope/vim-commentary'
  Plug 'tpope/vim-surround'
  Plug 'airblade/vim-gitgutter'
  Plug 'itchyny/lightline.vim'

  call plug#end()

  " Theme configuration
  " Configure Catppuccin flavor
  lua << EOF
  -- Check if the 'catppuccin' module exists before requiring it
  local has_catppuccin, catppuccin = pcall(require, "catppuccin")
  if has_catppuccin then
    catppuccin.setup({
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      background = { 
        light = "latte",
        dark = "mocha",
      },
      transparent_background = false,
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
  
  " Apply Catppuccin theme
  silent! colorscheme catppuccin
  
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
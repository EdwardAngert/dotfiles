" Personal Neovim configuration based on gitlab.com/EdwardAngert/nvim
" This file should be placed at ~/.config/nvim/personal.vim

" Basic settings that override the defaults in init.vim
set number
set norelativenumber  " Disable relativenumber from the main config
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set cursorline
set wildmenu
set hidden " keep undo history after buffer reload
set mouse=a
set guifont=Karambasi\ Book " If the font is installed, otherwise comment out

" Mark that we've loaded our own basic settings
let g:basic_settings_loaded = 1

" Custom plugins (these will be added to the default ones in init.vim)
let g:additional_plugins = [
  \'godlygeek/tabular',
  \'raphamorim/lucario',
  \'tpope/vim-fugitive',
  \'vim-airline/vim-airline',
  \'vim-airline/vim-airline-themes',
  \'plasticboy/vim-markdown',
  \'tanvirtin/monokai.nvim',
  \'scrooloose/nerdtree',
  \'Yggdroot/indentLine'
]

" Set preferred colorscheme
let g:preferred_colorscheme = 'monokai'

" Airline configuration (will be applied after plugins loaded)
augroup CustomConfig
  autocmd!
  autocmd VimEnter * silent! AirlineTheme bubblegum
  autocmd VimEnter * let g:airline#extensions#tabline#enabled=1
  autocmd VimEnter * let g:airline_powerline_fonts=1
  autocmd VimEnter * let g:airline#extensions#branch#enabled=1
augroup END

" Vim markdown settings
let g:vim_markdown_frontmatter = 1 " yaml syntax highlighting

" NERDTree settings
nnoremap <C-n> :NERDTreeToggle<CR>
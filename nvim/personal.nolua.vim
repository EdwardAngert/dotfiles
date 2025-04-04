" Personal Neovim configuration for environments without proper Lua support
" This provides a lightweight setup that avoids Lua-based plugins

" Mark that we've loaded our own custom plugins
let g:custom_plugins_loaded = 1

" Set basic settings
set number
set norelativenumber
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set cursorline
set wildmenu
set hidden
set mouse=a
set cmdheight=2

" Set a fallback color scheme
set background=dark
let g:preferred_colorscheme = 'default'

" Start with plugins that don't depend on Lua
call plug#begin('~/.vim/plugged')
  " Syntax and highlighting
  Plug 'sheerun/vim-polyglot'  " Better syntax support for many languages
  
  " Color schemes that don't depend on Lua
  Plug 'lifepillar/vim-solarized8'
  Plug 'morhetz/gruvbox'
  
  " Git integration
  Plug 'tpope/vim-fugitive'
  Plug 'airblade/vim-gitgutter'
  
  " Editing enhancements
  Plug 'tpope/vim-commentary'
  Plug 'tpope/vim-surround'
  Plug 'godlygeek/tabular'
  
  " File explorer
  Plug 'scrooloose/nerdtree'
  
  " Fuzzy finding without Telescope
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  
  " Lightweight status line
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
call plug#end()

" Basic color scheme configuration
silent! colorscheme gruvbox

" Configure airline
let g:airline_theme = 'gruvbox'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#branch#enabled = 1

" NERDTree settings
nnoremap <C-n> :NERDTreeToggle<CR>
let g:NERDTreeShowHidden = 1

" FZF mappings (alternative to Telescope)
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fh :Helptags<CR>
nnoremap <leader>fc :BLines<CR>
nnoremap <leader>fl :Lines<CR>

" Other useful mappings
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>e :e<Space>

" Navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Common Git operations
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gd :Git diff<CR>
nnoremap <leader>gb :Git blame<CR>

" Clipboard workarounds for restricted environments
if !has('clipboard') && executable('xclip')
  vnoremap <leader>y :w !xclip -selection clipboard<CR><CR>
  nnoremap <leader>p :r !xclip -selection clipboard -o<CR>
elseif !has('clipboard') && executable('xsel')
  vnoremap <leader>y :w !xsel --clipboard --input<CR><CR>
  nnoremap <leader>p :r !xsel --clipboard --output<CR>
endif
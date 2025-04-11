" Personal Neovim configuration with Catppuccin theme
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

" Set a reasonable fallback if Karambasi font is not available
if has('gui_running')
  " Try JetBrains Mono first (installed by our dotfiles)
  if !empty(globpath(&rtp, 'JetBrainsMono*.ttf'))
    set guifont=JetBrains\ Mono:h14
  elseif has('mac')
    set guifont=Menlo:h14
  else
    set guifont=DejaVu\ Sans\ Mono:h12
  endif
endif

" Define whether to override main config settings
let g:basic_settings_loaded = 0 " Set to 0 to use settings from both files, 1 to only use these

" Custom plugins (only add plugins not already in init.vim)
let g:additional_plugins = ['vim-airline/vim-airline', 'vim-airline/vim-airline-themes', 'scrooloose/nerdtree']

" Configure Catppuccin theme 
let g:preferred_colorscheme = 'catppuccin'
let g:catppuccin_flavour = 'mocha' " Options: latte, frappe, macchiato, mocha
let g:catppuccin_transparent = 0   " Set to 1 for transparent background

" Airline configuration (will be applied after plugins loaded)
augroup CustomConfig
  autocmd!
  autocmd VimEnter * silent! AirlineTheme catppuccin  " Use matching theme
  autocmd VimEnter * let g:airline#extensions#tabline#enabled=1
  autocmd VimEnter * let g:airline_powerline_fonts=1
  autocmd VimEnter * let g:airline#extensions#branch#enabled=1
augroup END

" NERDTree settings (for file browsing)
nnoremap <C-n> :NERDTreeToggle<CR>
let g:NERDTreeShowHidden = 1       " Show hidden files
let g:NERDTreeQuitOnOpen = 0       " Don't quit NERDTree when opening a file
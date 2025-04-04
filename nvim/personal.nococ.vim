" Personal Neovim configuration without CoC (when Node.js isn't available)
" This provides a fallback experience that still works well

" Mark that we've loaded our own custom plugins
let g:custom_plugins_loaded = 1

" Start with plugins that don't depend on Node.js
call plug#begin('~/.vim/plugged')
  " Syntax and highlighting
  Plug 'sheerun/vim-polyglot'  " Better syntax support for many languages
  
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
  Plug 'junegunn/vim-easy-align'
  Plug 'reedes/vim-pencil'
  
  " Markdown support
  Plug 'plasticboy/vim-markdown'
  Plug 'dhruvasagar/vim-table-mode'
  
  " Session management
  Plug 'tpope/vim-obsession'
  
  " Simple fuzzy find (doesn't need telescope)
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
call plug#end()

" Basic settings
set number
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set autoindent
set smartindent
set smarttab
set wildmenu
set hidden
set ignorecase
set smartcase
set incsearch
set hlsearch

" Enable built-in completion
set omnifunc=syntaxcomplete#Complete
inoremap <C-Space> <C-x><C-o>

" Theme configuration
let g:catppuccin_flavour = 'mocha'
silent! colorscheme catppuccin

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

" FZF mappings (replacement for Telescope)
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fc :BLines<CR>
nnoremap <leader>fr :History<CR>

" Git mappings
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gp :Git push<CR>
nnoremap <leader>gl :Git pull<CR>
nnoremap <leader>gd :Git diff<CR>
nnoremap <leader>gb :Git blame<CR>

" Table Mode
let g:table_mode_corner='|'
let g:table_mode_tableize_map = '<leader>tm'
let g:table_mode_realign_map = '<leader>tr'
nmap <leader>tt :TableModeToggle<CR>

" Markdown settings
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal = 2
let g:vim_markdown_conceal_code_blocks = 0
let g:vim_markdown_math = 1
let g:vim_markdown_toml_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_autowrite = 1

" Easy Align
xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

" When in markdown files, enable spell checking and pencil
augroup markdown_settings
  autocmd!
  autocmd FileType markdown,md setlocal spell spelllang=en_us
  autocmd FileType markdown,md call pencil#init({'wrap': 'soft'})
  autocmd FileType markdown,md setlocal conceallevel=2
augroup END
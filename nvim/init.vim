" Basic Settings
" These will be the base settings that apply to all installations
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
  
  " Clipboard configuration for various platforms
  if has('unix')
    if system('uname -s') =~ 'Darwin'
      " macOS - built-in clipboard should work
    else
      " Linux - try to use xclip or xsel if available
      if executable('xclip')
        let g:clipboard = {
          \ 'name': 'xclip',
          \ 'copy': {
          \    '+': 'xclip -selection clipboard',
          \    '*': 'xclip -selection clipboard',
          \  },
          \ 'paste': {
          \    '+': 'xclip -selection clipboard -o',
          \    '*': 'xclip -selection clipboard -o',
          \ },
          \ 'cache_enabled': 0,
          \ }
      elseif executable('xsel')
        let g:clipboard = {
          \ 'name': 'xsel',
          \ 'copy': {
          \    '+': 'xsel --clipboard --input',
          \    '*': 'xsel --clipboard --input',
          \  },
          \ 'paste': {
          \    '+': 'xsel --clipboard --output',
          \    '*': 'xsel --clipboard --output',
          \ },
          \ 'cache_enabled': 0,
          \ }
      endif
    endif
  endif
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
    " -------------------------------------------------------
    " LANGUAGE INTELLIGENCE & COMPLETION
    " -------------------------------------------------------
    
    " Full-featured language server protocol (LSP) client
    " Provides intelligent code completion, error checking, and more
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    let g:coc_disable_startup_warning = 1
    
    " Advanced syntax highlighting using incremental parsing library
    " Far better than regex-based highlighting, understands code structure
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    
    " -------------------------------------------------------
    " FILE NAVIGATION & SEARCH
    " -------------------------------------------------------
    
    " Dependency for telescope and other plugins
    " Provides lua utility functions for other plugins
    Plug 'nvim-lua/plenary.nvim'
    
    " Highly extendable fuzzy finder over lists
    " Used for searching files, buffers, grep, git operations, and more
    Plug 'nvim-telescope/telescope.nvim'
    
    " C port of FZF for faster searching with telescope
    " Makes searching noticeably faster, especially in large projects
    Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
    
    " -------------------------------------------------------
    " APPEARANCE & UI
    " -------------------------------------------------------
    
    " Modern, customizable theme with several variants
    " Offers soft, pleasing colors with good contrast
    Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
    
    " Lightweight, configurable status line 
    " Shows file info, mode, git branch, etc. in the status bar
    Plug 'itchyny/lightline.vim'
    
    " Shows vertical indent guides
    " Makes nested code blocks easier to distinguish visually
    Plug 'Yggdroot/indentLine'
    
    " -------------------------------------------------------
    " GIT INTEGRATION
    " -------------------------------------------------------
    
    " Complete git integration within vim
    " Run any git command within vim, view diffs, resolve conflicts
    Plug 'tpope/vim-fugitive'
    
    " Shows git diff markers in the sign column
    " Indicates added, modified, and removed lines
    Plug 'airblade/vim-gitgutter'
    
    " -------------------------------------------------------
    " EDITING ENHANCEMENTS
    " -------------------------------------------------------
    
    " Easy commenting of code
    " Toggle comments with gcc (line) or gc (selection)
    Plug 'tpope/vim-commentary'
    
    " Easily change surrounding quotes, brackets, tags
    " Change, add, or delete surroundings with simple commands
    Plug 'tpope/vim-surround'
    
    " Text alignment around delimiters
    " Align code on =, :, |, etc.
    Plug 'godlygeek/tabular'
    
    " Interactive text alignment
    " More interactive, easier to use version of tabular
    Plug 'junegunn/vim-easy-align'
    
    " -------------------------------------------------------
    " MARKDOWN & WRITING
    " -------------------------------------------------------
    
    " Better writing experience with soft wrapping
    " Improves text editing for prose, not just code
    Plug 'reedes/vim-pencil'
    
    " Enhanced markdown support
    " Better syntax highlighting, concealing, folding for markdown
    Plug 'plasticboy/vim-markdown'
    let g:vim_markdown_frontmatter = 1 " YAML syntax highlighting
    
    " Easy markdown table creation and formatting
    " Create, format, and manipulate tables with simple commands
    Plug 'dhruvasagar/vim-table-mode'
    
    " -------------------------------------------------------
    " WORKFLOW & PRODUCTIVITY
    " -------------------------------------------------------
    
    " Session management for persistent workflow
    " Save and restore open files, window layout, and more
    Plug 'tpope/vim-obsession'
    
    " Auto-formatting for many languages and file types
    " Format code on save or on demand with Neoformat command
    Plug 'sbdchd/neoformat'
    
    " Load additional plugins if specified
    if exists('g:additional_plugins') && type(g:additional_plugins) == 3  " Check if it's a list
      for plugin in g:additional_plugins
        execute 'Plug ' . "'" . plugin . "'"
      endfor
    endif
  endif

  call plug#end()

  " Load personal settings if they exist (after plugins but before applying theme)
  if filereadable(expand('~/.config/nvim/personal.vim'))
    source ~/.config/nvim/personal.vim
  endif

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
  " Fallback theme if no plugins or in minimal environments
  if !has('gui_running')
    set t_Co=256
  endif
  
  try
    silent! colorscheme default
  catch
    " Do nothing if colorscheme fails
  endtry
  
  " Basic file finder mappings for minimal environments
  nnoremap <leader>ff :find *
  nnoremap <leader>fg :grep<space>
  nnoremap <leader>fb :ls<cr>:b<space>
  
  " Add some useful basic mappings even without plugins
  nnoremap <leader>w :w<CR>
  nnoremap <leader>q :q<CR>
  nnoremap <leader>e :e 
  
  " Basic splits
  nnoremap <leader>v :vsplit<CR>
  nnoremap <leader>s :split<CR>
  
  " Navigation
  nnoremap <C-h> <C-w>h
  nnoremap <C-j> <C-w>j
  nnoremap <C-k> <C-w>k
  nnoremap <C-l> <C-w>l
endif

" Auto Commands
augroup custom_settings
  autocmd!
  " Markdown-specific settings
  autocmd FileType markdown,md setlocal spell spelllang=en_us
  autocmd FileType markdown,md call pencil#init({'wrap': 'soft'})
  autocmd FileType markdown,md setlocal conceallevel=2

  " Config file settings
  autocmd FileType yaml,json,toml setlocal tabstop=2 shiftwidth=2

  " Auto-format on save for certain file types
  autocmd BufWritePre *.js,*.jsx,*.ts,*.tsx,*.json,*.yaml,*.yml Neoformat
  
  " Auto-save when focus is lost
  autocmd FocusLost * silent! wall
augroup END

" -------------------------------------------------------
" PLUGIN CONFIGURATIONS
" -------------------------------------------------------

" -------------------------------------------------------
" MARKDOWN & WRITING
" -------------------------------------------------------

" Table Mode - for creating and manipulating markdown tables
let g:table_mode_corner='|'                          " Use markdown-style table corners
let g:table_mode_tableize_map = '<leader>tm'         " Convert text to table
let g:table_mode_realign_map = '<leader>tr'          " Realign existing table
nmap <leader>tt :TableModeToggle<CR>                 " Toggle table mode

" Vim-pencil - for better prose writing
let g:pencil#wrapModeDefault = 'soft'                " Use soft line wraps (virtual, not actual breaks)
let g:pencil#textwidth = 80                          " Target width for text
let g:pencil#conceallevel = 2                        " Hide markup for better readability

" Vim Markdown - enhanced markdown functionality
let g:vim_markdown_folding_disabled = 1              " Disable folding (can be overwhelming)
let g:vim_markdown_conceal = 2                       " Hide markup for better readability
let g:vim_markdown_conceal_code_blocks = 0           " Don't conceal code blocks
let g:vim_markdown_math = 1                          " Enable math rendering
let g:vim_markdown_toml_frontmatter = 1              " Support TOML frontmatter
let g:vim_markdown_strikethrough = 1                 " Enable strikethrough with ~~text~~
let g:vim_markdown_autowrite = 1                     " Auto-save when following links
let g:vim_markdown_edit_url_in = 'tab'               " Open URLs in a new tab
let g:vim_markdown_follow_anchor = 1                 " Follow named anchors

" -------------------------------------------------------
" PRODUCTIVITY TOOLS
" -------------------------------------------------------

" Neoformat - code formatting
let g:neoformat_try_node_exe = 1                     " Use local node modules for formatters when available

" Session management with Obsession
nnoremap <leader>ss :Obsession<CR>                   " Start/pause recording session
nnoremap <leader>sl :source Session.vim<CR>          " Load session

" -------------------------------------------------------
" GIT INTEGRATION
" -------------------------------------------------------

" Fugitive - git commands within Vim
nnoremap <leader>gs :Git<CR>                         " Git status
nnoremap <leader>gc :Git commit<CR>                  " Git commit
nnoremap <leader>gp :Git push<CR>                    " Git push
nnoremap <leader>gl :Git pull<CR>                    " Git pull
nnoremap <leader>gd :Git diff<CR>                    " Git diff
nnoremap <leader>gb :Git blame<CR>                   " Git blame

" -------------------------------------------------------
" TELESCOPE & SEARCH
" -------------------------------------------------------

" Telescope configuration with FZF integration
augroup TelescopeSetup
  autocmd!
  if has('nvim-0.5') && has('lua')
    autocmd VimEnter * silent! lua << EOF
      local status_ok, telescope = pcall(require, 'telescope')
      if status_ok then
        telescope.setup {
          extensions = {
            fzf = {
              fuzzy = true,
              override_generic_sorter = true,
              override_file_sorter = true,
              case_mode = "smart_case"
            }
          }
        }
        
        pcall(telescope.load_extension, 'fzf')
      end
EOF
  endif
augroup END

" Telescope key mappings
nnoremap <leader>fr :Telescope oldfiles<CR>          " Recently opened files (MRU)
nnoremap <leader>fc :Telescope current_buffer_fuzzy_find<CR>  " Search in current file
nnoremap <leader>fg :Telescope live_grep<CR>         " Search text in all files (grep)
nnoremap <leader>fb :Telescope buffers<CR>           " Browse open buffers

" -------------------------------------------------------
" TEXT EDITING HELPERS
" -------------------------------------------------------

" Easy Align - interactive alignment
xmap ga <Plug>(EasyAlign)                            " Start EasyAlign in visual mode (e.g., vipga=)
nmap ga <Plug>(EasyAlign)                            " Start EasyAlign for motion/text object (e.g., gaip=)

" -------------------------------------------------------
" CODE INTELLIGENCE
" -------------------------------------------------------

" CoC extensions for code intelligence
" Run this once: :CocInstall coc-json coc-yaml coc-toml coc-tsserver coc-markdownlint
let g:coc_global_extensions = ['coc-json', 'coc-yaml', 'coc-toml', 'coc-tsserver', 'coc-markdownlint']

" Install vim-plug message
if !filereadable(expand('~/.vim/autoload/plug.vim')) && !filereadable(expand('~/.local/share/nvim/site/autoload/plug.vim'))
  echo "vim-plug not installed. Install with:"
  echo "curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
endif
call plug#begin()
" Theme
Plug 'dracula/vim'
Plug 'bluz71/vim-nightfly-guicolors'
Plug 'tomasr/molokai'                                       " sublime theme
Plug 'dunstontc/vim-vscode-theme'                           " vscode theme
"File Explorer With Icons
Plug 'scrooloose/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'Xuyuanp/nerdtree-git-plugin'                          " show git status in file tree view
Plug 'itchyny/lightline.vim'                                " better look of vim status line
Plug 'itchyny/vim-gitbranch'                                " Git branch name for lightline
Plug 'airblade/vim-gitgutter'                               " A Vim plugin which shows a git diff in the 'gutter' (sign column)
Plug 'tpope/vim-fugitive'                                   " Git for Vim
Plug 'tpope/vim-rhubarb'                                    " Github integration for fugitive
"File Search
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
"Language Client
Plug 'neoclide/coc.nvim', {'branch': 'release'}
let g:coc_global_extensions = ['coc-emmet', 'coc-css', 'coc-html', 'coc-json', 'coc-prettier', 'coc-tsserver']
"Type Script Highlighting
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'
"Vim Rest Console
Plug 'diepm/vim-rest-console'
call plug#end()
"Config Section
"Enable Theming support, but kinda fukd up on mac terminal so i commented out
"the set
if (has("termguicolors"))
set termguicolors
endif
"Theme
colorscheme nightfly
syntax enable
filetype on
set nu
set autochdir
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = []
let g:NERDTreeStatusline = ''
" Automaticaly close nvim if NERDTree is only thing left open
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
" Toggle
nnoremap <silent> <C-b> :NERDTreeToggle<CR>
" open new split panes to right and below
set splitright
set splitbelow
" turn terminal to normal mode with escape
tnoremap <Esc> <C-\><C-n>
" start terminal in insert mode
au BufEnter * if &buftype == 'terminal' | :startinsert | endif
" open terminal on ctrl+n
function! OpenTerminal()
  split term://zsh
  resize 10
endfunction
nnoremap <c-n> :call OpenTerminal()<CR>
" use alt+hjkl to move between split/vsplit panels
tnoremap <A-h> <C-\><C-n><C-w>h
tnoremap <A-j> <C-\><C-n><C-w>j
tnoremap <A-k> <C-\><C-n><C-w>k
tnoremap <A-l> <C-\><C-n><C-w>l
nnoremap <A-h> <C-w>h
nnoremap <A-j> <C-w>j
nnoremap <A-k> <C-w>k
nnoremap <A-l> <C-w>l
"Fuzzy Finder
nnoremap <C-f> :Ag<CR>
nnoremap <C-p> :FZF ~<CR>
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-s': 'split',
  \ 'ctrl-v': 'vsplit'
  \}
"Requires  silverserarcher-ag
"used to ignore gitignore and npm files
let $FZF_DEFAULT_COMMAND = 'ag -g ""'

"COC <3
" Some servers have issues with backup files, see #649.
set nobackup
set nowritebackup

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes

inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)

nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" Use K to show documentation in preview window.
nnoremap <silent> K :call ShowDocumentation()<CR>


function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
"lightline config
let g:lightline = {
			\'colorscheme' : 'nightfly',
			\'active': {
				\'left':[['mode', 'paste'],
				\['readonly', 'relativepath', 'gitbranch', 'modified', 'Hello']]
				\},
				\'component_function':{
				\'gitbranch' : 'gitbranch#name'
				\},
				\}

function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction


"settingz imported from previous vimrc
set nocompatible
"filetype off
set foldmethod=indent
set foldlevel=99

nnoremap <space> za
au BufNewFile,BufRead *.py
    \ set tabstop=4|
    \ set softtabstop=4|
    \ set shiftwidth=4|
"    \ set textwidth=79|
    \ set expandtab|
    \ set autoindent|
    \ set fileformat=unix|

au BufNewFile,BufRead *.c
    \ set tabstop=4|
    \ set softtabstop=4|
    \ set shiftwidth=4|
"    \ set textwidth=79|
    \ set expandtab|
    \ set autoindent|
    \ set fileformat=unix|

"Set Up esc mapping
inoremap jj <esc>

"Leader Key Set Up
nnoremap <SPACE> <Nop>
let mapleader = " "
"map <leader>b :bp<enter>
"map <leader>d :bd<enter>
"map <leader>n :bn<enter>
map <leader>w :w<enter>
map <leader>q :q<enter>
map <Leader>a ggVG
map <leader>j :tabprevious<enter>
map <leader>k :tabnext<enter>
map <leader>hl :nohl<enter>
nnoremap <leader>ev :vsplit $MYVIMRC<cr>
nnoremap <leader>sv :source $MYVIMRC<cr>

"Mapping Normal Mode window switching to ctrl
map <C-k> <C-w>k
map <C-j> <C-w>j 
map <C-l> <C-w>l 
map <C-h> <C-w>h 
map <leader>= <C-w>=

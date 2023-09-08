--vim plugins
local Plug = vim.fn['plug#']
vim.call('plug#begin', '~/.config/nvim/plugged')
-- Theme
Plug 'dracula/vim'
Plug 'bluz71/vim-nightfly-guicolors'
Plug 'tomasr/molokai'                                       -- sublime theme
Plug 'dunstontc/vim-vscode-theme'                           -- vscode theme

--File Explorer With Icons
Plug 'scrooloose/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'Xuyuanp/nerdtree-git-plugin'                          -- show git status in file tree view
Plug 'itchyny/lightline.vim'                                -- better look of vim status line
Plug 'itchyny/vim-gitbranch'                                -- Git branch name for lightline
Plug 'airblade/vim-gitgutter'                               -- A Vim plugin which shows a git diff in the 'gutter' (sign column)
Plug 'tpope/vim-fugitive'                                   -- Git for Vim
Plug 'tpope/vim-rhubarb'                                    -- Github integration for fugitive

--FZF Plugins
Plug('junegunn/fzf', {
  ['do'] = function()
    vim.call('fzf#install')
  end
})
Plug 'junegunn/fzf.vim'

vim.call('plug#end')

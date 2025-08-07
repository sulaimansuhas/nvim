-- Install package manager
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
-- Git related plugins
  require('config.gitplugs'),
-- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',
-- Neo Tree
  require('config.neotree'),
-- Autocompletion
  require('config.autocomplete'),
-- Formatter setup
  require('config.formatter'),
-- Linter setup
  require('config.linter'),
-- Git Gutter Signs And More
  require('config.gitsigns'),
-- Useful plugin to show you pending keybinds.
  { 'folke/which-key.nvim',  opts = {} },
-- Setup Theme
  require('config.theme').config,
-- Setup Indentation Markers
  require('config.indent-blankline').config,
-- Setup Telescope
  require('config.telescope').config,

  -- NOTE: This is where your plugins related to LSP can be installed.
  --  The configuration is done below. Search for lspconfig to find it below.
  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs to stdpath for neovim
      { 'williamboman/mason.nvim', config = true },
      'williamboman/mason-lspconfig.nvim',

      -- Useful status updates for LSP
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim',       tag = 'legacy', opts = {} },

      -- Additional lua configuration, makes nvim stuff amazing!
      'folke/neodev.nvim',
    },
  },


  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    -- See `:help lualine.txt`
    opts = {
      options = {
        icons_enabled = false,
        --theme = 'dracula',
        component_separators = '|',
        section_separators = '',
      },
    },
  },
  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim',         opts = {} },


  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
  },
}, {})

vim.g.fugitive_gitlab_domains={['git@gitlab.turing.bio:turing/turingdb.git'] = 'https://gitlab.turing.bio/turing/turingdb.git'}

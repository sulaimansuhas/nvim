--Basic Key Rebinds
--Leader Rebinding
vim.api.nvim_set_keymap('n', '<Space>', '<Nop>', { noremap = true })
vim.g.mapleader = ' '
--
vim.api.nvim_set_keymap('i', 'jj', '<Esc>', { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>q', ':q<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>a', 'ggVG', { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>j', ':tabprevious<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>k', ':tabnext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<Leader>hl', ':nohl<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '<C-w>k', { noremap = true })
vim.api.nvim_set_keymap('n', '<C-j>', '<C-w>j', { noremap = true })
vim.api.nvim_set_keymap('n', '<C-l>', '<C-w>l', { noremap = true })
vim.api.nvim_set_keymap('n', '<C-h>', '<C-w>h', { noremap = true })
vim.api.nvim_set_keymap('n', '<leader>=', '<C-w>=', { noremap = true })

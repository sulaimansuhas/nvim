-- [[ Basic Keymaps ]]
vim.api.nvim_set_keymap('n', '<Space>', '<Nop>', { noremap = true })
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

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

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })


-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>d', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

-- Copy&Paste
vim.keymap.set({'n', 'v'}, '<leader>y', '"+y', { desc = 'Copy To Clipboard' })
vim.keymap.set({'n'}, '<leader>Y', '"+yg_', { desc = 'Copy To Clipboard Till The EOF' })
vim.keymap.set({'n'}, '<leader>yy', '"+yy', { desc = 'Copy To Line To Clipboard' })
vim.keymap.set({'n','v'}, '<leader>p', '"+p', { desc = 'Paste From Clipboard After The Cursor' })
vim.keymap.set({'n','v'}, '<leader>P', '"+P', { desc = 'Paste From Clipboard before The Cursor' })

--FZF and AG config
vim.api.nvim_set_keymap('n', '<C-f>', ':Ag<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<C-p>', ':FZF ~<CR>', { noremap = true })

vim.g.fzf_action = {
    ['ctrl-t'] = 'tab split',
    ['ctrl-s'] = 'split',
    ['ctrl-v'] = 'vsplit',
}

vim.env.FZF_DEFAULT_COMMAND = 'ag -g ""'



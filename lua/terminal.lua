--Terminal Config

function StartTerminalInsertMode()
  if vim.bo.buftype == 'terminal' then
    vim.cmd('startinsert')
  end
end

function OpenTerminal()
  vim.cmd('split term://zsh')
  vim.cmd('resize 10')
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
  pattern = '*',
  callback = function() StartTerminalInsertMode() end,
})


vim.api.nvim_set_keymap('n', '<C-n>', ':lua OpenTerminal()<CR>', { silent = true })
vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-n>', { noremap = true })


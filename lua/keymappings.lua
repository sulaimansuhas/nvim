-- [[ Basic Keymaps ]]
vim.api.nvim_set_keymap('n', '<Space>', '<Nop>', { noremap = true })
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.api.nvim_set_keymap('i', 'jk', '<Esc>', { noremap = true })
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

-- Fold Commands
vim.keymap.set({'n','v'}, '<leader><enter>', 'za', { desc = "Toggle Fold Under Cursor"})
vim.keymap.set({'n','v'}, '<C-enter>', 'zA', { desc = "Toggle All Folds Recursively"})
--vim.keymap.set({'n','v'}, '<leader>r', 'zR', { desc = "Toggle Folds Under Cursor"})
--vim.keymap.set({'n','v'}, '<leader>m', 'zM', { desc = "Toggle All Folds"})
vim.keymap.set({'n','v'}, '<leader>fo', function()
  if vim.o.foldlevel == 0 then
    vim.cmd('set foldlevel=99')
  else
    vim.cmd('set foldlevel=0')
  end
end, { desc = 'Toggle all folds' })



-- Header/Source Toggle
local function find_counterpart(callback)
  local ft = vim.bo.filetype
  if ft ~= 'c' and ft ~= 'cpp' then return end

  local function fallback()
    local current = vim.api.nvim_buf_get_name(0)
    local base = current:match('(.+)%.[^%.]+$')
    local ext = current:match('%.([^%.]+)$')
    local candidates = {}
    if ext == 'h' or ext == 'hpp' then
      candidates = { base .. '.cpp', base .. '.cc', base .. '.cxx' }
    elseif ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
      candidates = { base .. '.h', base .. '.hpp' }
    end
    for _, candidate in ipairs(candidates) do
      if vim.fn.filereadable(candidate) == 1 then callback(candidate); return end
    end
    vim.notify('No counterpart file found', vim.log.levels.WARN)
  end

  local has_clangd = false
  for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = 0 })) do
    if client.name == 'clangd' then has_clangd = true; break end
  end

  if has_clangd then
    local params = { textDocument = { uri = vim.uri_from_bufnr(0) } }
    vim.lsp.buf_request(0, 'textDocument/switchSourceHeader', params, function(err, result)
      if err or not result or result == '' then fallback()
      else callback(vim.uri_to_fname(result)) end
    end)
  else
    fallback()
  end
end

local _split_partner_win = nil

vim.keymap.set('n', '<leader>o', function()
  find_counterpart(function(path)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == path then
        local target = (_split_partner_win and vim.api.nvim_win_is_valid(_split_partner_win))
          and _split_partner_win or win
        vim.api.nvim_win_close(target, false)
        _split_partner_win = nil
        return
      end
    end
    vim.cmd('vsplit ' .. vim.fn.fnameescape(path))
    _split_partner_win = vim.api.nvim_get_current_win()
  end)
end, { desc = 'Toggle header/source split' })

vim.keymap.set('n', '<leader>O', function()
  find_counterpart(function(path)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
  end)
end, { desc = 'Switch to header/source in current window' })

-- Custom Commands
-- vim.api.nvim_set_keymap('n', '<Leader>jf', ':Jsonfmt', { noremap = true, silent = true })

--nerdtree config
vim.g.NERDTreeShowHidden = 1
vim.g.NERDTreeMinimalUI = 1
vim.g.NERDTreeIgnore = {}
vim.g.NERDTreeStatusline = ''

--close vim if nerdtree is the only a nerdtree buffer open
function CloseNERDTreeOnEnter()
    if vim.fn.winnr("$") == 1 and vim.b.NERDTree and vim.b.NERDTree.isTabTree() then
        vim.cmd("q")
    end
end


vim.api.nvim_create_autocmd({"BufEnter"}, {
  pattern = '*',
  callback = function() CloseNERDTreeOnEnter() end,
})

vim.api.nvim_set_keymap('n','<C-b>', ':NERDTreeToggle<CR>',{noremap = true, silent = true })

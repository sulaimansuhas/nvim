local M = {}

M.setup= function()
  require('nightfox').setup({
    options = {
      transparent = true
    }
  })
  vim.cmd("colorscheme terafox")
end

M.config = {
   "EdenEast/nightfox.nvim"
}

return M

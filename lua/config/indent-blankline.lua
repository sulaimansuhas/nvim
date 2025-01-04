-- Setup blankline indentation

local M = {}

M.config = {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help indent_blankline.txt`
    main = "ibl",
    opts = {},
}

M.setup = function()
  require('ibl').setup(
    {
      indent = { char = "┇" }
    }

  )
end

return M

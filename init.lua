
-- <><><><><><><><> Custom Commands <><><><><><><><> -- 
vim.api.nvim_create_user_command('Jsonfmt', function()
	vim.cmd([[%!jq '.']])
end,{})
-- <><><><><><><><><><><><><><><><><><><><><><><><> -- 

require('keymappings')
require('plugins')
require('options')
require('lsp')
require('config.telescope').setup()
require('config.theme')
require('config.indent-blankline').setup()
require('config.treesitter')






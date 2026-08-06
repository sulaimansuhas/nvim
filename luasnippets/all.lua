-- Snippets available in every filetype.
local ls = require 'luasnip'
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmt = require('luasnip.extras.fmt').fmt

return {
  -- Current date, e.g. 2026-07-27
  s('date', f(function()
    return os.date '%Y-%m-%d'
  end)),

  s('todo', fmt('TODO({}): {}', { i(1, 'suhas'), i(2, 'description') })),
}

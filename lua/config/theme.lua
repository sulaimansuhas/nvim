local M = {}

local mode_file = vim.fn.expand('~/.config/theme-mode')
local scheme_file = vim.fn.expand('~/.config/theme-scheme')

local function read_line(path)
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path)
    if lines and lines[1] and lines[1] ~= '' then return lines[1] end
  end
end

local function write_line(path, value)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  vim.fn.writefile({ value }, path)
end

local function read_mode()
  local m = read_line(mode_file)
  if m == 'light' or m == 'dark' then return m end
  return 'dark'
end

local function read_scheme()
  return read_line(scheme_file) or 'everforest'
end

local function apply_scheme()
  pcall(vim.cmd.colorscheme, read_scheme())
end

M.config = {
  'sainnhe/everforest',
  lazy = false,
  priority = 1000,
  config = function()
    vim.g.everforest_enable_italic = true
    vim.g.everforest_background = 'hard'
    vim.g.everforest_diagnostic_virtual_text = 'colored'
    vim.o.background = read_mode()
    apply_scheme()

    -- Persist whichever colorscheme is active (covers :Telescope colorscheme,
    -- :colorscheme <name>, and the toggle below).
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function(args)
        if args.match and args.match ~= '' then
          write_line(scheme_file, args.match)
        end
      end,
    })

    vim.api.nvim_create_autocmd('FocusGained', {
      callback = function()
        local mode = read_mode()
        if mode ~= vim.o.background then
          vim.o.background = mode
          apply_scheme()
        end
      end,
    })

    vim.keymap.set('n', '<leader>tt', function()
      local new = vim.o.background == 'dark' and 'light' or 'dark'
      vim.o.background = new
      write_line(mode_file, new)
      apply_scheme()
      if vim.env.TMUX then
        vim.fn.jobstart({ 'tmux', 'source-file', vim.fn.expand('~/.tmux.conf') }, { detach = true })
      end
    end, { desc = 'Toggle light/dark theme' })

    vim.keymap.set('n', '<leader>tc', function()
      require('telescope.builtin').colorscheme({ enable_preview = true })
    end, { desc = 'Pick colorscheme' })
  end,
}

return M

local M = {}

-- Per-repo persistent "reviewed" tracking for the git status picker.
-- Stored as a flat { [relPath] = true } table inside the repo's git dir,
-- so it lives and dies with the clone and never touches the working tree.
local function gs_db_path()
  local out = vim.fn.systemlist({ 'git', 'rev-parse', '--absolute-git-dir' })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == '' then
    return vim.fn.stdpath('state') .. '/telescope_gs_reviewed.json'
  end
  return out[1] .. '/telescope_gs_reviewed.json'
end

local function gs_load_db(path)
  local f = io.open(path, 'r')
  if not f then return {} end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then return {} end
  return data
end

local function gs_save_db(path, db)
  local f = io.open(path, 'w')
  if not f then return end
  f:write(vim.json.encode(db))
  f:close()
end

local function gs_repo_root()
  local out = vim.fn.systemlist({ 'git', 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == '' then
    return vim.loop.cwd()
  end
  return out[1]
end

-- Fingerprint a repo-relative file so reviewed marks can be invalidated when
-- the file changes after being marked. Renames ("OLD -> NEW") hash NEW.
local function gs_file_hash(rel)
  local arrow = rel:find(' -> ', 1, true)
  if arrow then rel = rel:sub(arrow + 4) end
  local path = gs_repo_root() .. '/' .. rel
  if vim.fn.filereadable(path) == 0 then return 'GONE' end
  return vim.fn.sha256(table.concat(vim.fn.readfile(path, 'b'), '\n'))
end

M.config =  {
  -- Fuzzy Finder (files, lsp, etc)
  { 'nvim-telescope/telescope.nvim', branch = '0.1.x', dependencies = {
    'nvim-lua/plenary.nvim',
    {
        "nvim-telescope/telescope-live-grep-args.nvim" ,
        version = "^1.0.0",
    }
  } },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built.
  -- Only load if `make` is available. Make sure you have the system
  -- requirements installed.
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    -- NOTE: If you are having trouble with this installation,
    --       refer to the README for telescope-fzf-native for more instructions.
    build = 'make',
    cond = function()
      return vim.fn.executable 'make' == 1
    end,
  }
}
M.setup = function()
  require('telescope').setup {
    defaults = {
      mappings = {
        i = {
          ['<C-u>'] = false,
          ['<C-d>'] = false,
        },
      },
    },
    pickers = {
      colorscheme = {
        enable_preview = true
      }
    }
  }

  -- Enable telescope fzf native, if installed
  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'live_grep_args')

  -- See `:help telescope.builtin`
  vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
  vim.keymap.set('n', '<leader><space>', function()
  require('telescope.builtin').buffers({ sort_mru=true })
  end, { desc = '[ ] Find existing buffers' })
  vim.keymap.set('n', '<leader>/', require('telescope.builtin').current_buffer_fuzzy_find,
    { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set("n", "<leader>fg", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
  vim.keymap.set('n', '<leader>gf', require('telescope.builtin').git_files, { desc = 'Search [G]it [F]iles' })
  vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sk', require('telescope.builtin').keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>gs', function()
    local builtin       = require('telescope.builtin')
    local actions       = require('telescope.actions')
    local action_state  = require('telescope.actions.state')
    local entry_display = require('telescope.pickers.entry_display')
    local make_entry    = require('telescope.make_entry')

    local db_path  = gs_db_path()
    local reviewed = gs_load_db(db_path)

    -- A mark stores the file's content hash at mark time; if the file has
    -- changed since, it is no longer "reviewed" -- drop the mark.
    local dirty = false
    for rel, saved in pairs(reviewed) do
      local now = gs_file_hash(rel)
      if saved == true then -- legacy boolean mark: adopt current content
        reviewed[rel] = now
        dirty = true
      elseif saved ~= now then
        reviewed[rel] = nil
        dirty = true
      end
    end
    if dirty then gs_save_db(db_path, reviewed) end

    local displayer = entry_display.create({
      separator = ' ',
      items = { { width = 1 }, { width = 9 }, { remaining = true } },
    })
    local gen = make_entry.gen_from_git_status({})

    builtin.git_status({
      entry_maker = function(entry)
        local e = gen(entry)
        if not e then return end
        e.display = function(tbl)
          local mark = reviewed[tbl.value] and '✓' or ' '
          local staged   = (tbl.status or ''):sub(1, 1)
          local unstaged = (tbl.status or ''):sub(2, 2)
          local label, hl
          if staged ~= ' ' and unstaged ~= ' ' and unstaged ~= '' then
            label, hl = 'both', 'DiagnosticWarn'
          elseif staged ~= ' ' then
            label, hl = 'staged', 'DiagnosticOk'
          elseif unstaged == '?' then
            label, hl = 'untracked', 'Comment'
          else
            label, hl = 'unstaged', 'DiagnosticHint'
          end
          return displayer({ { mark, 'DiagnosticOk' }, { label, hl }, tbl.value })
        end
        return e
      end,
      attach_mappings = function(prompt_bufnr, map)
        -- Open the picked file in a real editor window, never the neo-tree sidebar
        -- (neo-tree refuses file buffers, which otherwise leaves you staring at the tree).
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          local target
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype ~= 'neo-tree' then
              target = win
              break
            end
          end
          if target then
            vim.api.nvim_set_current_win(target)
          end
          local rel = entry.value
          -- git status renames come through as "OLD -> NEW"; take NEW.
          local arrow = rel and rel:find(' -> ', 1, true)
          if arrow then rel = rel:sub(arrow + 4) end
          local file_path = gs_repo_root() .. '/' .. rel
          vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
        end)

        local function toggle_reviewed()
          local entry = action_state.get_selected_entry()
          if not entry then return end
          reviewed[entry.value] = (not reviewed[entry.value]) and gs_file_hash(entry.value) or nil
          gs_save_db(db_path, reviewed)
          local picker = action_state.get_current_picker(prompt_bufnr)
          -- refresh() resets the selection to the top; restore it so marking
          -- doesn't lose your place in the list.
          local row = picker:get_selection_row()
          local callbacks = { unpack(picker._completion_callbacks) }
          picker:register_completion_callback(function(self)
            self:set_selection(row)
            self._completion_callbacks = callbacks
          end)
          picker:refresh(picker.finder, { reset_prompt = false })
        end
        map({ 'i', 'n' }, '<C-r>', toggle_reviewed)
        return true
      end,
    })
  end, { desc = '[G]it [S]tatus' })
end

return M

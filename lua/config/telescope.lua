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

-- Fingerprint a root-relative file so reviewed marks can be invalidated when
-- the file changes after being marked. Renames ("OLD -> NEW") hash NEW.
local function gs_file_hash(root, rel)
  local arrow = rel:find(' -> ', 1, true)
  if arrow then rel = rel:sub(arrow + 4) end
  local path = root .. '/' .. rel
  if vim.fn.filereadable(path) == 0 then return 'GONE' end
  return vim.fn.sha256(table.concat(vim.fn.readfile(path, 'b'), '\n'))
end

-- A mark stores the file's content hash at mark time; if the file has
-- changed since, it is no longer "reviewed" -- drop the mark.
local function gs_prune_stale(db_path, reviewed, root)
  local dirty = false
  for rel, saved in pairs(reviewed) do
    local now = gs_file_hash(root, rel)
    if saved == true then -- legacy boolean mark: adopt current content
      reviewed[rel] = now
      dirty = true
    elseif saved ~= now then
      reviewed[rel] = nil
      dirty = true
    end
  end
  if dirty then gs_save_db(db_path, reviewed) end
end

-- Open a file in a real editor window, never the neo-tree sidebar
-- (neo-tree refuses file buffers, which leaves you staring at the tree).
local function open_in_code_window(file_path)
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
  vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
end

-- <C-r> handler shared by the git and jj status pickers: toggle the mark,
-- then refresh without losing the current selection (refresh resets to top).
local function make_toggle_reviewed(prompt_bufnr, reviewed, db_path, root)
  local action_state = require('telescope.actions.state')
  return function()
    local entry = action_state.get_selected_entry()
    if not entry then return end
    reviewed[entry.value] = (not reviewed[entry.value]) and gs_file_hash(root, entry.value) or nil
    gs_save_db(db_path, reviewed)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local row = picker:get_selection_row()
    local callbacks = { unpack(picker._completion_callbacks) }
    picker:register_completion_callback(function(self)
      self:set_selection(row)
      self._completion_callbacks = callbacks
    end)
    picker:refresh(picker.finder, { reset_prompt = false })
  end
end

-- Root-relative path of the current buffer, or nil when outside the root.
local function gs_buf_rel(root)
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= '' and name:sub(1, #root + 1) == root .. '/' then
    return name:sub(#root + 2)
  end
end

-- One-shot on_complete hook: open the picker with the current file's row
-- selected when it is in the list; otherwise telescope's default first row
-- stands. Removes itself so typing/refreshes don't re-snap the selection.
local function gs_preselect(cur_rel)
  return {
    function(picker)
      picker._completion_callbacks = {}
      if not cur_rel then return end
      local index = 0
      for entry in picker.manager:iter() do
        index = index + 1
        local value = entry.value
        local arrow = value:find(' -> ', 1, true)
        if value == cur_rel or (arrow and value:sub(arrow + 4) == cur_rel) then
          pcall(function() picker:set_selection(picker:get_row(index)) end)
          return
        end
      end
    end,
  }
end

local function jj_root()
  local out = vim.fn.systemlist({ 'jj', 'workspace', 'root' })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == '' then return nil end
  return out[1]
end

-- Reviewed-marks db for jj workspaces: share the git-dir db when the git dir
-- really belongs to this root (colocated or a real worktree). A foreign
-- gitdir pointer (secondary jj workspace hack) would collide with the other
-- workspace's marks, so those use their own .jj dir instead.
local function js_db_path(root)
  local out = vim.fn.systemlist({ 'git', '-C', root, 'rev-parse', '--absolute-git-dir' })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= ''
    and (out[1] == root .. '/.git' or out[1]:find('/%.git/worktrees/')) then
    return out[1] .. '/telescope_gs_reviewed.json'
  end
  return root .. '/.jj/telescope_gs_reviewed.json'
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
    local root     = gs_repo_root()
    gs_prune_stale(db_path, reviewed, root)

    local displayer = entry_display.create({
      separator = ' ',
      items = { { width = 1 }, { width = 9 }, { remaining = true } },
    })
    local gen = make_entry.gen_from_git_status({})

    builtin.git_status({
      on_complete = gs_preselect(gs_buf_rel(root)),
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
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          local rel = entry.value
          -- git status renames come through as "OLD -> NEW"; take NEW.
          local arrow = rel and rel:find(' -> ', 1, true)
          if arrow then rel = rel:sub(arrow + 4) end
          open_in_code_window(root .. '/' .. rel)
        end)

        map({ 'i', 'n' }, '<C-r>', make_toggle_reviewed(prompt_bufnr, reviewed, db_path, root))
        return true
      end,
    })
  end, { desc = '[G]it [S]tatus' })

  -- jj-native status picker: same reviewed marks and <C-r> toggle as
  -- <leader>gs, but fed by `jj diff --summary` so it works in jj
  -- workspaces (including pure ones where git_status fails).
  --
  -- Per-workspace session state: the search filter is restored on reopen,
  -- and the diff source (extra `jj diff` args, e.g. "--from main") sticks
  -- until changed via <C-e> in the picker or :JjStatus <args>.
  local js_session = {}

  local function jj_status_open(args_override)
    local pickers       = require('telescope.pickers')
    local finders       = require('telescope.finders')
    local conf          = require('telescope.config').values
    local actions       = require('telescope.actions')
    local action_state  = require('telescope.actions.state')
    local entry_display = require('telescope.pickers.entry_display')

    local root = jj_root()
    if not root then
      vim.notify('Not inside a jj workspace', vim.log.levels.WARN)
      return
    end
    local state = js_session[root] or {}
    js_session[root] = state
    if args_override ~= nil then
      state.args = args_override ~= '' and args_override or nil
    end
    local extra = {}
    if state.args then
      -- Shell-like tokenizing: 'quoted' / "quoted" segments stay one
      -- argument and lose their quotes (there is no shell in between, so
      -- quotes would otherwise reach jj verbatim and break revsets).
      local s, i = state.args, 1
      while i <= #s do
        local c = s:sub(i, i)
        if c:match('%s') then
          i = i + 1
        elseif c == '"' or c == "'" then
          local close = s:find(c, i + 1, true)
          if not close then
            table.insert(extra, s:sub(i + 1))
            break
          end
          table.insert(extra, s:sub(i + 1, close - 1))
          i = close + 1
        else
          local stop = s:find('%s', i) or (#s + 1)
          table.insert(extra, s:sub(i, stop - 1))
          i = stop
        end
      end
    end

    local cmd = { 'jj', '--color=never', '--no-pager', 'diff', '--summary' }
    vim.list_extend(cmd, extra)
    local summary = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify('jj diff failed:\n' .. table.concat(summary, '\n'), vim.log.levels.ERROR)
      return
    end

    local entries = {}
    for _, line in ipairs(summary) do
      local status, rel = line:match('^(%u)%s+(.+)$')
      if status and rel then
        -- jj renames print "R {old => new}"; open/hash the new path.
        local pre, _, new, post = rel:match('^(.*){(.*) => (.*)}(.*)$')
        if pre then rel = pre .. new .. post end
        -- jj prints paths relative to the cwd; store them root-relative so
        -- marks stay stable across sessions started in different directories.
        local abs = vim.fn.simplify(vim.fn.fnamemodify(rel, ':p'))
        if abs:sub(1, #root + 1) == root .. '/' then
          rel = abs:sub(#root + 2)
        end
        table.insert(entries, { status = status, rel = rel })
      end
    end
    if #entries == 0 then
      vim.notify('jj: no changes' .. (state.args and (' for: jj diff ' .. state.args) or ' in working copy'),
        vim.log.levels.INFO)
      return
    end

    local db_path  = js_db_path(root)
    local reviewed = gs_load_db(db_path)
    gs_prune_stale(db_path, reviewed, root)

    local labels = {
      M = { 'modified', 'DiagnosticHint' },
      A = { 'added', 'DiagnosticOk' },
      D = { 'deleted', 'DiagnosticError' },
      R = { 'renamed', 'DiagnosticWarn' },
      C = { 'copied', 'DiagnosticWarn' },
    }
    local displayer = entry_display.create({
      separator = ' ',
      items = { { width = 1 }, { width = 9 }, { remaining = true } },
    })

    pickers.new({}, {
      on_complete = gs_preselect(gs_buf_rel(root)),
      prompt_title = 'jj status — ' .. vim.fn.fnamemodify(root, ':t')
        .. (state.args and (' [' .. state.args .. ']') or ''),
      default_text = state.filter,
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          return {
            value = e.rel,
            status = e.status,
            ordinal = e.status .. ' ' .. e.rel,
            display = function(tbl)
              local mark = reviewed[tbl.value] and '✓' or ' '
              local label = labels[tbl.status] or { tbl.status, 'Comment' }
              return displayer({ { mark, 'DiagnosticOk' }, { label[1], label[2] }, tbl.value })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      -- Diff preview like the git_status builtin has. `root:"…"` filesets keep
      -- root-relative paths working when nvim's cwd is a subdirectory.
      previewer = require('telescope.previewers').new_termopen_previewer({
        title = 'jj diff',
        get_command = function(entry)
          local preview = { 'jj', '--no-pager', '--color=always', 'diff' }
          vim.list_extend(preview, extra)
          table.insert(preview, 'root:"' .. entry.value .. '"')
          return preview
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        -- Keep the last-typed filter so the next open restores it.
        vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
          buffer = prompt_bufnr,
          callback = function()
            state.filter = action_state.get_current_line()
          end,
        })

        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          open_in_code_window(root .. '/' .. entry.value)
        end)
        map({ 'i', 'n' }, '<C-r>', make_toggle_reviewed(prompt_bufnr, reviewed, db_path, root))

        -- <C-e>: change the diff source (empty input resets to working copy).
        map({ 'i', 'n' }, '<C-e>', function()
          actions.close(prompt_bufnr)
          vim.ui.input({ prompt = 'jj diff args (empty = working copy) > ', default = state.args or '' },
            function(input)
              if input == nil then return end -- cancelled
              vim.schedule(function() jj_status_open(input) end)
            end)
        end)
        return true
      end,
    }):find()
  end

  vim.keymap.set('n', '<leader>js', function() jj_status_open() end, { desc = '[J]j [S]tatus' })
  vim.api.nvim_create_user_command('JjStatus', function(opts)
    -- No args = open with whatever source is saved; reset happens via <C-e>.
    jj_status_open(opts.args ~= '' and opts.args or nil)
  end, { nargs = '*', desc = 'jj status picker; args are extra `jj diff` args, e.g. --from main' })
end

return M

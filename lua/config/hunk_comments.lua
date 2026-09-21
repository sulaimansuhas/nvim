-- Per-hunk comments persisted in .git/, keyed by content hash so they survive
-- line shifts. Comments whose hash no longer matches a current gitsigns hunk
-- are surfaced as "orphaned" — kept around for the user to dismiss explicitly.

local M = {}

local ns = vim.api.nvim_create_namespace('hunk_comments')
local buf_cache = {}

local function paths(bufnr)
  if buf_cache[bufnr] ~= nil then
    return buf_cache[bufnr] or nil
  end
  local fp = vim.api.nvim_buf_get_name(bufnr)
  if fp == '' then
    buf_cache[bufnr] = false
    return nil
  end
  local dir = vim.fn.fnamemodify(fp, ':h')
  local root_out = vim.fn.systemlist({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error ~= 0 or not root_out[1] or root_out[1] == '' then
    buf_cache[bufnr] = false
    return nil
  end
  local gdir_out = vim.fn.systemlist({ 'git', '-C', dir, 'rev-parse', '--absolute-git-dir' })
  if vim.v.shell_error ~= 0 or not gdir_out[1] or gdir_out[1] == '' then
    buf_cache[bufnr] = false
    return nil
  end
  local root = root_out[1]
  if fp:sub(1, #root) ~= root then
    buf_cache[bufnr] = false
    return nil
  end
  local p = {
    file = fp,
    root = root,
    gdir = gdir_out[1],
    rel  = fp:sub(#root + 2),
    db   = gdir_out[1] .. '/nvim_hunk_comments.json',
  }
  buf_cache[bufnr] = p
  return p
end

local function load_db(p)
  local f = io.open(p.db, 'r')
  if not f then return {} end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then return {} end
  return data
end

local function save_db(p, db)
  local f = io.open(p.db, 'w')
  if not f then return end
  f:write(vim.json.encode(db))
  f:close()
end

local function hunk_hash(hunk)
  -- hunk.lines contains the unified-diff body (+/- prefixed). Hashing it
  -- pins the comment to the content, not the line range.
  return vim.fn.sha256(table.concat(hunk.lines or {}, '\n'))
end

local function hunk_preview(hunk)
  for _, line in ipairs(hunk.lines or {}) do
    local prefix = line:sub(1, 1)
    if prefix == '+' or prefix == '-' then
      local body = line:sub(2):gsub('^%s+', ''):gsub('%s+$', '')
      if #body > 0 then
        if #body > 60 then body = body:sub(1, 57) .. '...' end
        return prefix .. ' ' .. body
      end
    end
  end
  return '(empty)'
end

local function get_hunks(bufnr)
  local ok, gs = pcall(require, 'gitsigns')
  if not ok then return {} end
  return gs.get_hunks(bufnr) or {}
end

local function hunk_at_cursor(bufnr)
  local hunks = get_hunks(bufnr)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  for _, h in ipairs(hunks) do
    local s = h.added.start
    local e = s + math.max(h.added.count, 1) - 1
    if line >= s and line <= e then return h end
  end
  return nil
end

local function render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local p = paths(bufnr)
  if not p then return end
  local db = load_db(p)
  local file_comments = db[p.rel] or {}
  if vim.tbl_isempty(file_comments) then return end

  local hunks = get_hunks(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local matched = {}
  for _, h in ipairs(hunks) do
    local hash = hunk_hash(h)
    if file_comments[hash] then
      matched[hash] = true
      local lnum = math.max(h.added.start - 1, 0)
      if lnum < line_count then
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
          virt_text = { { ' 💬', 'DiagnosticHint' } },
          virt_text_pos = 'eol',
        })
      end
    end
  end

  local orphaned = 0
  for hash, _ in pairs(file_comments) do
    if not matched[hash] then orphaned = orphaned + 1 end
  end
  if orphaned > 0 and line_count > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
      virt_text = { { string.format(' 💬⚠ %d orphaned', orphaned), 'DiagnosticWarn' } },
      virt_text_pos = 'eol',
    })
  end
end

local function open_comment_float(bufnr, hunk)
  local p = paths(bufnr)
  if not p then return end
  local hash = hunk_hash(hunk)
  local db = load_db(p)
  local existing = (db[p.rel] or {})[hash]
  local preview = hunk_preview(hunk)

  local cbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[cbuf].bufhidden = 'wipe'
  vim.bo[cbuf].filetype = 'markdown'
  if existing then
    vim.api.nvim_buf_set_lines(cbuf, 0, -1, false,
      vim.split(existing.text, '\n', { plain = true }))
  end

  local width = math.min(74, vim.o.columns - 4)
  local height = 10
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local title = string.format(' %s:%d  %s ', p.rel, hunk.added.start, preview)
  local win = vim.api.nvim_open_win(cbuf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'left',
    footer = ' <CR>=save  q=quit  (empty body deletes) ',
    footer_pos = 'right',
  })

  local closed = false
  local function close()
    if closed then return end
    closed = true
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end

  local function save_and_close()
    local lines = vim.api.nvim_buf_get_lines(cbuf, 0, -1, false)
    local text = table.concat(lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
    local cur = load_db(p)
    cur[p.rel] = cur[p.rel] or {}
    if text == '' then
      cur[p.rel][hash] = nil
    else
      cur[p.rel][hash] = {
        text = text,
        preview = preview,
        updated_at = os.time(),
      }
    end
    if vim.tbl_isempty(cur[p.rel]) then cur[p.rel] = nil end
    save_db(p, cur)
    close()
    render(bufnr)
  end

  vim.keymap.set('n', '<CR>', save_and_close, { buffer = cbuf, nowait = true })
  vim.keymap.set('n', 'q', close, { buffer = cbuf, nowait = true })
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = cbuf,
    callback = save_and_close,
  })

  if not existing then vim.cmd('startinsert') end
end

local function pick_orphans(bufnr)
  local p = paths(bufnr)
  if not p then return end
  local db = load_db(p)
  local file_comments = db[p.rel] or {}
  if vim.tbl_isempty(file_comments) then
    vim.notify('No comments on this file', vim.log.levels.INFO)
    return
  end

  local current = {}
  for _, h in ipairs(get_hunks(bufnr)) do current[hunk_hash(h)] = true end

  local entries = {}
  for hash, c in pairs(file_comments) do
    if not current[hash] then
      table.insert(entries, {
        hash = hash,
        text = c.text,
        preview = c.preview or '',
        updated_at = c.updated_at or 0,
      })
    end
  end
  if #entries == 0 then
    vim.notify('No orphaned comments on this file', vim.log.levels.INFO)
    return
  end
  table.sort(entries, function(a, b) return a.updated_at > b.updated_at end)

  local pickers      = require('telescope.pickers')
  local finders      = require('telescope.finders')
  local conf         = require('telescope.config').values
  local actions      = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers   = require('telescope.previewers')

  pickers.new({}, {
    prompt_title = 'Orphaned Hunk Comments — ' .. p.rel,
    finder = finders.new_table {
      results = entries,
      entry_maker = function(e)
        local one = (e.text:gsub('\n', ' ⏎ '))
        return {
          value = e,
          display = string.format('%-44s │ %s', e.preview, one),
          ordinal = e.preview .. ' ' .. e.text,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        local lines = { '── original hunk ──', entry.value.preview, '', '── comment ──' }
        for _, l in ipairs(vim.split(entry.value.text, '\n', { plain = true })) do
          table.insert(lines, l)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    },
    attach_mappings = function(prompt_bufnr, map)
      local function dismiss()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local cur = load_db(p)
        if cur[p.rel] then
          cur[p.rel][entry.value.hash] = nil
          if vim.tbl_isempty(cur[p.rel]) then cur[p.rel] = nil end
          save_db(p, cur)
        end
        actions.close(prompt_bufnr)
        render(bufnr)
        vim.notify('Comment dismissed', vim.log.levels.INFO)
      end
      map({ 'i', 'n' }, '<C-d>', dismiss)
      return true
    end,
  }):find()
end

-- Parse `git diff -U0` for the whole repo into { [rel] = { [hash] = start_line } }
-- so live/orphaned status can be computed without loading every buffer.
local function repo_live_hunks(p)
  local out = vim.fn.systemlist({ 'git', '-C', p.root, 'diff', '-U0', '--no-color', '--no-ext-diff' })
  if vim.v.shell_error ~= 0 then return {} end
  local live, rel, body, start = {}, nil, nil, nil
  local function flush()
    if rel and body and #body > 0 then
      live[rel] = live[rel] or {}
      live[rel][vim.fn.sha256(table.concat(body, '\n'))] = start
    end
    body, start = nil, nil
  end
  for _, line in ipairs(out) do
    local new_rel = line:match('^diff %-%-git a/.- b/(.+)$')
    if new_rel then
      flush()
      rel = new_rel
    elseif line:find('^@@') then
      flush()
      start = tonumber(line:match('^@@ %-%d+,?%d* %+(%d+)')) or 1
      body = {}
    elseif body then
      local prefix = line:sub(1, 1)
      if (prefix == '+' or prefix == '-') and line:sub(1, 3) ~= '+++' and line:sub(1, 3) ~= '---' then
        table.insert(body, line)
      end
    end
  end
  flush()
  return live
end

-- Repo-wide picker over every comment in the db, live and orphaned alike.
local function pick_all(bufnr)
  local p = paths(bufnr)
  if not p then return end
  local db = load_db(p)
  if vim.tbl_isempty(db) then
    vim.notify('No hunk comments in this repo', vim.log.levels.INFO)
    return
  end

  local live = repo_live_hunks(p)
  local entries = {}
  for rel, file_comments in pairs(db) do
    for hash, c in pairs(file_comments) do
      table.insert(entries, {
        rel = rel,
        hash = hash,
        text = c.text,
        preview = c.preview or '',
        updated_at = c.updated_at or 0,
        lnum = live[rel] and live[rel][hash] or nil,
      })
    end
  end
  table.sort(entries, function(a, b) return a.updated_at > b.updated_at end)

  local pickers      = require('telescope.pickers')
  local finders      = require('telescope.finders')
  local conf         = require('telescope.config').values
  local actions      = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers   = require('telescope.previewers')

  pickers.new({}, {
    prompt_title = 'Hunk Comments — ' .. vim.fn.fnamemodify(p.root, ':t'),
    finder = finders.new_table {
      results = entries,
      entry_maker = function(e)
        local status = e.lnum and '💬' or '⚠ '
        local loc = e.lnum and (e.rel .. ':' .. e.lnum) or (e.rel .. ' (orphaned)')
        local one = (e.text:gsub('\n', ' ⏎ '))
        return {
          value = e,
          display = string.format('%s %-44s │ %s', status, loc, one),
          ordinal = e.rel .. ' ' .. e.preview .. ' ' .. e.text,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer {
      define_preview = function(self, entry)
        local e = entry.value
        local lines = {
          e.rel .. (e.lnum and (':' .. e.lnum) or '  (hunk no longer present)'),
          '',
          '── original hunk ──', e.preview, '', '── comment ──',
        }
        for _, l in ipairs(vim.split(e.text, '\n', { plain = true })) do
          table.insert(lines, l)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    },
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry then return end
        local e = entry.value
        vim.cmd('edit ' .. vim.fn.fnameescape(p.root .. '/' .. e.rel))
        if e.lnum then
          pcall(vim.api.nvim_win_set_cursor, 0, { e.lnum, 0 })
        else
          vim.notify('Comment is orphaned — hunk no longer present', vim.log.levels.WARN)
        end
      end)
      local function dismiss()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local e = entry.value
        local cur = load_db(p)
        if cur[e.rel] then
          cur[e.rel][e.hash] = nil
          if vim.tbl_isempty(cur[e.rel]) then cur[e.rel] = nil end
          save_db(p, cur)
        end
        actions.close(prompt_bufnr)
        render(bufnr)
        vim.notify('Comment dismissed', vim.log.levels.INFO)
      end
      map({ 'i', 'n' }, '<C-d>', dismiss)
      return true
    end,
  }):find()
end

function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not paths(bufnr) then return end

  vim.keymap.set('n', '<leader>gc', function()
    local h = hunk_at_cursor(bufnr)
    if not h then
      vim.notify('No hunk under cursor', vim.log.levels.INFO)
      return
    end
    open_comment_float(bufnr, h)
  end, { buffer = bufnr, desc = '[G]it hunk [C]omment' })

  vim.keymap.set('n', '<leader>gC', function()
    pick_orphans(bufnr)
  end, { buffer = bufnr, desc = '[G]it hunk [C]omments (orphans picker)' })

  vim.keymap.set('n', '<leader>ga', function()
    pick_all(bufnr)
  end, { buffer = bufnr, desc = '[G]it hunk comments — [A]ll in repo' })

  local group = vim.api.nvim_create_augroup('HunkComments_buf_' .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
    group = group,
    buffer = bufnr,
    callback = function() render(bufnr) end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'GitSignsUpdate',
    callback = function() render(bufnr) end,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    buffer = bufnr,
    callback = function() buf_cache[bufnr] = nil end,
  })

  render(bufnr)
end

return M

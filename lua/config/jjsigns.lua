-- Gutter signs + hunk navigation for *pure* jj workspaces (no .git), where
-- gitsigns cannot attach. Colocated repos keep gitsigns and skip this, so
-- there is never a double gutter.
return {
  'evanphx/jjsigns.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  config = function()
    require('jjsigns').setup({ attach = { auto = false } })

    -- Root of the jj workspace that jj (not git) should own signs for.
    -- Returns nil when gitsigns is trustworthy there: truly colocated
    -- (.git directory) or a real git worktree (own per-worktree index).
    -- A `.git` *pointer file* into another checkout's primary git dir
    -- (e.g. the turingdb-claude cmake hack) shares that checkout's index,
    -- so git hunks would mix workspaces — jj owns those buffers.
    local function pure_jj_root(file)
      local root = vim.fs.root(vim.fs.dirname(file), '.jj')
      if not root then return nil end
      local dotgit = vim.uv.fs_stat(root .. '/.git')
      if not dotgit then return root end
      if dotgit.type == 'directory' then return nil end -- truly colocated
      local gitdir = vim.fn.systemlist({ 'git', '-C', root, 'rev-parse', '--absolute-git-dir' })[1]
      if vim.v.shell_error == 0 and gitdir and gitdir:find('/%.git/worktrees/') then
        return nil -- proper git worktree
      end
      return root -- foreign gitdir pointer: treat as pure jj
    end

    local function jj_hunks(bufnr)
      local file = vim.api.nvim_buf_get_name(bufnr)
      local root = pure_jj_root(file)
      if not root then return {} end
      local base = require('jjsigns.config').config.base
      local lines = require('jjsigns.jj').get_file_diff(file:sub(#root + 2), base, nil, root)
      return lines and require('jjsigns.diff').parse_diff(lines) or {}
    end

    -- Jump to the next/previous hunk start, wrapping around like gitsigns.
    local function jump_hunk(dir)
      local hunks = jj_hunks(0)
      if #hunks == 0 then
        vim.notify('No jj hunks in file', vim.log.levels.INFO)
        return
      end
      local cur = vim.api.nvim_win_get_cursor(0)[1]
      local idx
      if dir > 0 then
        for i, h in ipairs(hunks) do
          if h.start_line > cur then
            idx = i
            break
          end
        end
        idx = idx or 1
      else
        for i = #hunks, 1, -1 do
          if hunks[i].start_line < cur then
            idx = i
            break
          end
        end
        idx = idx or #hunks
      end
      vim.api.nvim_win_set_cursor(0, { math.max(hunks[idx].start_line, 1), 0 })
      -- Same feedback gitsigns gives on <leader>gn/gp.
      vim.api.nvim_echo({ { string.format('Hunk %d of %d', idx, #hunks), 'None' } }, false, {})
    end

    -- Hunks with their diff body lines (jjsigns' parser keeps positions only).
    local function jj_hunks_with_lines(bufnr)
      local file = vim.api.nvim_buf_get_name(bufnr)
      local root = pure_jj_root(file)
      if not root then return {} end
      local base = require('jjsigns.config').config.base
      local out = require('jjsigns.jj').get_file_diff(file:sub(#root + 2), base, nil, root)
      if not out then return {} end
      local hunks, cur = {}, nil
      for _, line in ipairs(out) do
        local new_start, new_count = line:match('^@@ %-%d+,?%d* %+(%d+),?(%d*) @@')
        if new_start then
          cur = {
            header = line,
            lines = {},
            new_start = tonumber(new_start),
            new_count = new_count ~= '' and tonumber(new_count) or 1,
          }
          table.insert(hunks, cur)
        elseif cur and (line:sub(1, 1) == '+' or line:sub(1, 1) == '-')
          and line:sub(1, 3) ~= '+++' and line:sub(1, 3) ~= '---' then
          table.insert(cur.lines, line)
        end
      end
      return hunks
    end

    -- Float the diff of the hunk under the cursor (gitsigns preview_hunk-alike).
    local function preview_hunk()
      local bufnr = vim.api.nvim_get_current_buf()
      local cur_line = vim.api.nvim_win_get_cursor(0)[1]
      for _, h in ipairs(jj_hunks_with_lines(bufnr)) do
        local last = h.new_start + math.max(h.new_count, 1) - 1
        if cur_line >= h.new_start and cur_line <= last then
          local content = { h.header }
          vim.list_extend(content, h.lines)
          local pbuf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, content)
          vim.bo[pbuf].filetype = 'diff'
          vim.bo[pbuf].bufhidden = 'wipe'
          local width = 0
          for _, l in ipairs(content) do
            width = math.max(width, vim.fn.strdisplaywidth(l))
          end
          local win = vim.api.nvim_open_win(pbuf, false, {
            relative = 'cursor',
            row = 1,
            col = 0,
            width = math.max(10, math.min(width + 1, vim.o.columns - 4)),
            height = math.min(#content, 20),
            style = 'minimal',
            border = 'rounded',
          })
          -- Deferred so the mapping's own CursorMoved doesn't instantly close it.
          vim.schedule(function()
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'BufLeave', 'InsertEnter' }, {
              once = true,
              buffer = bufnr,
              callback = function()
                if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
              end,
            })
          end)
          return
        end
      end
      vim.notify('No jj hunk under cursor', vim.log.levels.INFO)
    end

    local function try_attach(bufnr)
      local file = vim.api.nvim_buf_get_name(bufnr)
      if file == '' or vim.b[bufnr].jjsigns_attached or not pure_jj_root(file) then return end
      vim.b[bufnr].jjsigns_attached = true
      require('jjsigns.attach').attach_to_buffer(bufnr)
      -- Mirror the gitsigns hunk maps so muscle memory works in pure jj repos.
      vim.keymap.set('n', '<leader>gn', function() jump_hunk(1) end,
        { buffer = bufnr, desc = '[G]o to [N]ext Hunk (jj)' })
      vim.keymap.set('n', '<leader>gp', function() jump_hunk(-1) end,
        { buffer = bufnr, desc = '[G]o to [P]revious Hunk (jj)' })
      vim.keymap.set('n', '<leader>ph', preview_hunk,
        { buffer = bufnr, desc = '[P]review [H]unk (jj)' })
    end

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
      group = vim.api.nvim_create_augroup('JjSignsPureAttach', { clear = true }),
      callback = function(args) try_attach(args.buf) end,
    })

    -- Lazy-loading means buffers opened before the plugin loaded missed the
    -- autocmd above; attach them now.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then try_attach(buf) end
    end

    -- Change which revision the gutter and the <leader>gn/gp hunk jumps
    -- diff against: `:JjBase main`, `:JjBase @--`, etc. Plain `:JjBase`
    -- shows the current base; the default is @- (working copy's parent).
    vim.api.nvim_create_user_command('JjBase', function(opts)
      local cfg = require('jjsigns.config').config
      if opts.args == '' then
        vim.notify('jj signs base: ' .. cfg.base)
        return
      end
      -- The revset goes to jj as a single argv element (no shell), so
      -- spaces are fine and surrounding quotes would only hurt: strip them.
      local rev = opts.args:gsub('^"(.*)"$', '%1'):gsub("^'(.*)'$", '%1')
      local check = vim.fn.systemlist({
        'jj', '--no-pager', 'log', '--no-graph', '-r', rev, '--limit', '1', '-T', 'change_id',
      })
      if vim.v.shell_error ~= 0 then
        vim.notify('Invalid revset "' .. rev .. '":\n' .. table.concat(check, '\n'), vim.log.levels.ERROR)
        return
      end
      cfg.base = rev
      require('jjsigns.signs').refresh_all_buffers()
      vim.notify('jj signs base set to ' .. cfg.base)
    end, { nargs = '*', desc = 'Set base revision for jj gutter signs and hunk jumps (default @-)' })
  end,
}

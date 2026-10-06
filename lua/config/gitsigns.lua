  return {
    -- Adds git releated signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      -- See `:help gitsigns.txt`
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      linehl = false,
      numhl = true,
      word_diff = false,
      on_attach = function(bufnr)
        -- In jj workspaces whose `.git` is a pointer file into another
        -- checkout's primary git dir (not a real worktree), git sees that
        -- checkout's index against this workspace's files — hunks would mix
        -- workspaces. Bail out; jjsigns owns these buffers.
        local file = vim.api.nvim_buf_get_name(bufnr)
        local jjroot = file ~= '' and vim.fs.root(vim.fs.dirname(file), '.jj') or nil
        if jjroot then
          local dotgit = vim.uv.fs_stat(jjroot .. '/.git')
          if dotgit and dotgit.type ~= 'directory' then
            local gitdir = vim.fn.systemlist({ 'git', '-C', jjroot, 'rev-parse', '--absolute-git-dir' })[1]
            if not (vim.v.shell_error == 0 and gitdir and gitdir:find('/%.git/worktrees/')) then
              return false
            end
          end
        end

        vim.keymap.set('n', '<leader>gp', require('gitsigns').prev_hunk,
          { buffer = bufnr, desc = '[G]o to [P]revious Hunk' })
        vim.keymap.set('n', '<leader>gn', require('gitsigns').next_hunk, { buffer = bufnr, desc = '[G]o to [N]ext Hunk' })
        vim.keymap.set('n', '<leader>ph', require('gitsigns').preview_hunk, { buffer = bufnr, desc = '[P]review [H]unk' })

        local function highlight_menu()
          local gs = require('gitsigns')
          local cfg = require('gitsigns.config').config
          local items = {
            { key = 'linehl',             label = 'Line highlight',    toggle = gs.toggle_linehl },
            { key = 'numhl',              label = 'Number highlight',  toggle = gs.toggle_numhl },
            { key = 'word_diff',          label = 'Word diff',         toggle = gs.toggle_word_diff },
            { key = 'signcolumn',         label = 'Gutter signs',      toggle = gs.toggle_signs },
            { key = 'show_deleted',       label = 'Deleted lines',     toggle = gs.toggle_deleted },
            { key = 'current_line_blame', label = 'Current line blame', toggle = gs.toggle_current_line_blame },
          }
          vim.ui.select(items, {
            prompt = 'Toggle gitsigns highlight',
            format_item = function(item)
              return string.format('[%s] %s', cfg[item.key] and 'x' or ' ', item.label)
            end,
          }, function(choice)
            if not choice then return end
            pcall(choice.toggle)
            vim.schedule(highlight_menu)
          end)
        end
        vim.keymap.set('n', '<leader>gh', highlight_menu,
          { buffer = bufnr, desc = '[G]it [H]ighlight toggles' })

        -- Per-hunk comments (<leader>gc / gC / ga)
        require('config.hunk_comments').attach(bufnr)
      end,
    },
  }

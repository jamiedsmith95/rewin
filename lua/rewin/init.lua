local conf = require("telescope.config").values
local action_state = require "telescope.actions.state"
local sorters = require "telescope.sorters"
local previewer = require "telescope.previewers"
local layouts = require "telescope.pickers.layout_strategies"
local actions = require "telescope.actions"
local finders = require "telescope.finders"
local themes = require "telescope.themes"
local pickers = require "telescope.pickers"
local M = {}

-- need the ability to find a file that you want to reference
-- or
-- need to be able to create a point within current buffer to reference later.

-- or just show list of marks, can make wrapper function if marks are not used much
-- neet to be able to create small floating window with the reference buffer at the point the reference was made

-- set a mark at location to reference



M.floatingList = function(opts, data)
  -- displays floating list, creates autocommands to keep variables consistent and removes the augroup when closed.
  if #data == 0 then
    print('No marks found')
    return
  end
  local width = 40
  local color = vim.api.nvim_exec2('colo', { output = true })
  local bufnr = vim.api.nvim_create_buf(false, true)
  local cbuf = vim.fn.bufnr('%')
  local height = #data

  local floatingListDefaults = {
    relative = "cursor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = 'minimal',
    anchor = 'NW',
    border = { "▄", "▄", "▄", "█", "▀", "▀", "▀", "█" },
  }
  --If opts.floatinglist doesn't exist, assume provided opts is meant to be opts.floatinglist and fill with saved defaults where needed.
  if vim.api.nvim_eval('exists("opts.floatinglist")') == 0 then
    local optsBackup = vim.api.nvim_get_var('rewinOpts')
    opts.floatinglist = vim.tbl_deep_extend('keep', optsBackup.floatinglist, floatingListDefaults)
  end

  local win_id = vim.api.nvim_open_win(bufnr, true, opts.floatinglist)

  local groupId = vim.api.nvim_create_augroup('floatListGroup', {})

  -- vim.api.nvim_create_autocmd({ 'WinClosed' },
  --   { command = "let g:haveWin='false' | echo 'bufnr sets falses '", group = groupId, buffer = bufnr })
  vim.api.nvim_create_autocmd({ 'WinLeave' },
    {
      callback = function()
        M.closeWin()
        vim.api.nvim_win_close(win_id, true)
        vim.api.nvim_del_augroup_by_name('floatListGroup')
      end,
      group = groupId,
      buffer = bufnr,
    })
  vim.api.nvim_create_autocmd({ 'BufCreate', 'WinNew', 'BufNew', 'CursorMoved' },
    { command = "set winblend=30", group = groupId, buffer = bufnr })
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    callback = function()
      vim.api.nvim_exec('set winblend=30', {})
      local line = vim.fn.line('.')
      local lineContent = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if vim.api.nvim_get_var('haveWin') == true then
        M.closeWin()
      end
      M.makeWin(lineContent, opts)
    end,
    buffer = bufnr
  })
  vim.keymap.set({ 'n', 'i' }, "<CR>", function() M.selectItem() end, { buffer = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)

  return { win_id, bufnr }
end

M.selectItem = function()
  -- selects the current item from the list, default mapping is <CR>

  vim.api.nvim_del_augroup_by_name('floatListGroup')
  local line = vim.fn.line('.')
  vim.api.nvim_win_close(0, true)
  vim.api.nvim_set_var('haveWin', true)
end


M.setBuf = function()
  -- set mark "R" at the current cursor location
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local ok = vim.api.nvim_buf_set_mark(0, 'R', line, 1, {})
  return true
end

local function getBuf(mark)
  -- get the mark and buffer to view in the window
  local markLocation = vim.api.nvim_get_mark(tostring(mark), {}) -- row, col, buffer, bufferName
  local buffer = markLocation[3]
  vim.api.nvim_set_var('refRow', markLocation[1])
  vim.api.nvim_set_var('refBuf', buffer)
end

M.winSwitch = function()
  -- Enter floating window, if already in it then leave. If there is no window open the default
  opts = vim.api.nvim_get_var('rewinOpts')
  local gotRef = vim.api.nvim_eval('exists("g:refWin")')
  if gotRef == 0 then
    M.listSelect(opts)
    return
  end
  local win = vim.g.refWin
  if (vim.api.nvim_get_current_win() == win) then
    vim.api.nvim_set_current_win(vim.api.nvim_get_var('winSave'))
  elseif (win == nil) or (win == false) then
    M.makeWin("R", opts)
  else
    vim.api.nvim_set_var('winSave', vim.api.nvim_get_current_win())
    vim.api.nvim_set_current_win(win)
  end
end

M.closeWin = function()
  -- close window if exists, if not do nothing.
  if vim.api.nvim_eval('exists("g:refWin")') == 0 then
    return
  end
  local win = vim.g.refWin
  if win == false then
  else
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_set_var('refWin', false)
    vim.api.nvim_set_var('haveWin', false)
  end
end

local function getResults()
  -- filter the marks and return only the ones in A-Z0-9
  -- TODO: need to filter and remove the marks that are auto set, perhaps by them having column =0?
  local marks = vim.api.nvim_exec2('marks', { output = true })

  local results = {}
  local done = {}

  for m in string.gmatch(marks.output, "([^\r\n]+)") do
    if vim.tbl_contains(done, m) then goto continue end

    local str = string.match(m, '^%s(%w)')
    table.insert(done, m)
    if str then
      if string.len(str) > 1 then
      elseif string.match(str, "[0-9A-Z]") and vim.api.nvim_get_mark(str, {}) then
        table.insert(results, str)
      end
    end
    ::continue::
  end
  return results
end

M.listSelect = function(opts)
  -- get list of marks and pass to floatingList
  local data = getResults()
  M.floatingList(opts, data)
end


M.makeWin = function(mark, opts)
  local makeWinDefaults = {
    relative = 'cursor',
    row = -2,
    col = 50,
    title = 'Reference',
    width = 80,
    height = 15,
    focusable = false,
    anchor = 'SW',
    border = 'single',
    style = 'minimal'
  }

  if vim.api.nvim_win_get_config(0).relative ~= '' and vim.api.nvim_win_get_config(0).focusable == false then
    print('Cannot create new reference window from a floating window.')
    return
  end
  if vim.api.nvim_eval('exists("opts.makewin")') == 0 then
    local optsBackup = vim.api.nvim_get_var('rewinOpts')

    opts.makewin = vim.tbl_extend('keep', optsBackup.makewin, makeWinDefaults)
  end
  if mark == "" then
    getBuf("R")
  -- elseif mark then -- see if mark is more than a single char
  --   print('Mark must only be one character')
  --   return
  else
    getBuf(mark)
  end


  -- refresh the window if already open.
  if vim.api.nvim_get_var('haveWin') == true then
    M.closeWin()
    -- M.makeWin(mark, opts)
    -- return
  end
  local buffer = vim.api.nvim_get_var('refBuf')
  local row = vim.api.nvim_get_var('refRow')
  local cbuf = vim.fn.bufnr('%')


  -- groups only active during this function, group is then deleted.
  vim.api.nvim_create_augroup('madeWin', {})
  vim.api.nvim_create_autocmd({ 'WinNew', 'BufCreate' }, { command = "set winblend=45", group = madeWin, buffer = cbuf })
  vim.api.nvim_create_autocmd({ 'WinNew', 'BufCreate' },
    { command = "set winblend=45", group = madeWin, buffer = buffer })
  vim.api.nvim_create_autocmd({ 'BufDelete' },
    { command = "let g:haveWin='false' | let g:refWin='false'", buffer = buffer })
  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { command = "let g:haveWin='false' | let g:refwin='false'", buffer = buffer })

  local win = vim.api.nvim_open_win(buffer, false,
    opts.makewin)
  if (vim.api.nvim_win_get_config(0).relative ~= '' and buffer == vim.api.nvim_win_get_buf(0)) or row > vim.api.nvim_buf_line_count(buffer) then
    print('it rel and the same')
  else
    print('win and row',win,row)

    -- vim.api.nvim_win_set_cursor(win, { row, 0 })
  end

  vim.api.nvim_set_var('haveWin', true)
  vim.api.nvim_set_var('refWin', win)
  vim.api.nvim_del_augroup_by_name('madeWin')
end

M.setup = function(opts)
  local makeWinDefaults = {
    relative = 'cursor',
    row = -2,
    col = 50,
    title = 'Reference',
    width = 80,
    height = 15,
    focusable = false,
    anchor = 'SW',
    border = 'single',
    style = 'minimal'
  }

  local floatingListDefaults = {
    relative = "cursor",
    row = 1,
    col = 1,
    width = 30,
    height = 13,
    style = 'minimal',
    anchor = 'NW',
    border = { "▄", "▄", "▄", "█", "▀", "▀", "▀", "█" },
  }


  if vim.api.nvim_eval('exists("opts.makewin")') == 0 then
    opts.makewin = makeWinDefaults
  else
    opts.makewin = vim.tbl_deep_extend('keep', opts.makewin, makeWinDefaults)
  end
  if vim.api.nvim_eval('exists("opts.floatinglist")') == 0 then
    opts.floatinglist = floatingListDefaults
  else
    opts.floatinglist = vim.tbl_deep_extend('keep', floatingListOpts, floatingListDefaults)
  end

  vim.api.nvim_set_var('rewinOpts', opts)


  if vim.api.nvim_eval('exists("g:haveWin")') == 1 then
    if vim.g.haveWin == true then
      M.closeWin()
      M.makeWin(vim.g.refBuf, opts)
    else
      vim.api.nvim_set_var('haveWin', false)
      vim.api.nvim_set_var('refWin', false)
    end
  else
    vim.api.nvim_set_var('haveWin', false)
    vim.api.nvim_set_var('refWin', false)
  end



  vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
  vim.keymap.set('n', '<leader>ww', function() M.makeWin("R", opts) end)
  vim.keymap.set('n', '<leader>we', function() M.winSwitch() end)
  vim.keymap.set('n', '<leader>wc', function() M.closeWin() end)

  vim.keymap.set('n', '<leader>f', function() M.listSelect(opts) end)
end
return M

--
-- need rto be able to go into the reference window to adjust the location or yank a chunk etc..
--

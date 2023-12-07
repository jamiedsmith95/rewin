local M = {}



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

  vim.api.nvim_create_autocmd({ 'WinLeave', 'WinClosed' },
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
    { command = "set winblend=0 | call nvim_win_set_hl_ns(0,0)", group = groupId, buffer = bufnr })
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    callback = function()
      vim.api.nvim_exec('set winblend=0', {})
      local line = vim.fn.line('.')
      local lineContent = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if vim.api.nvim_get_var('haveWin') == true then
        M.closeWin()
      end
      M.makeWin(lineContent, opts)
    end,
    buffer = bufnr
  })
  vim.keymap.set({ 'n', 'i' }, "<Plug>selectItem",function() M.selectItem() end, {buffer = bufnr })
  -- vim.keymap.set({ 'n', 'i' }, "<CR>", function() M.selectItem() end, { buffer = bufnr })

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
  if vim.api.nvim_eval('exists("g:refWin")') == 0 or vim.g.haveWin == false then
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
  -- filter the marks and return only the ones in A-Z01
  -- TODO: need to filter and remove the marks that are auto set, perhaps by them having column =0?
  local marks = vim.api.nvim_exec2('marks', { output = true })

  local results = {}
  local rowAndFiles = {}
  local bad = {}
  local all = {}

  for m in string.gmatch(marks.output, "([^\r\n]+)") do
    local splitString = vim.split(m, '[%s]+')

    local str = splitString[2]
    local row = splitString[3]
    local col = splitString[4]
    local file = splitString[5]




    if string.match(str, "[A-Z01]") and vim.api.nvim_get_mark(str, {})[4] ~= {0,0,0,''}  then

      local temp = { row, file }
      if vim.tbl_contains(rowAndFiles, temp) then goto continue end
      table.insert(rowAndFiles, { count = temp })
      temp = { str, row, file }
      table.insert(all, { count = temp })
    end
    ::continue::
  end

  for idx, rowFile in pairs(rowAndFiles) do
    if vim.tbl_contains(bad, rowFile.count) then
      --skip
    else
      table.insert(results, all[idx].count[1])
    end
  end
  table.sort(results) 

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
  else
    getBuf(mark)
  end
  local marks = getResults()
  if #marks == 0 then 
    M.listSelect(opts)
    return
  end


  --don't open window if there already is one, in the list selection the next autocommand trigger will open another.
  if vim.api.nvim_get_var('haveWin') == true then
    M.closeWin()
  end
  local buffer = vim.api.nvim_get_var('refBuf')
  local row = vim.api.nvim_get_var('refRow')
  local cbuf = vim.fn.bufnr('%')


  -- groups only active during this function, group is then deleted.
  vim.api.nvim_create_augroup('madeWin', {})
  vim.api.nvim_create_autocmd({ 'WinNew', 'BufCreate' }, { command = "set winblend=0", group = madeWin, buffer = cbuf })
  vim.api.nvim_create_autocmd({ 'WinNew', 'BufCreate' },
    { command = "set winblend=0 | call nvim_win_set_hl_ns(0,0)", group = madeWin, buffer = buffer })
  vim.api.nvim_create_autocmd({ 'BufDelete' },
    { command = "let g:haveWin='false' | let g:refWin='false'", buffer = buffer })
  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { command = "let g:haveWin='false' | let g:refwin='false'", buffer = buffer })




  local win = vim.api.nvim_open_win(buffer, false,
    opts.makewin)
  if (vim.api.nvim_win_get_config(0).relative ~= '' and (buffer == vim.api.nvim_win_get_buf(0)) or row > vim.api.nvim_buf_line_count(buffer)) then
    vim.api.nvim_del_current_line()
  elseif vim.api.nvim_eval("exists('#floatListGroup#WinLeave')") then
    vim.api.nvim_win_set_cursor(win, { row, 1 })
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



  -- vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
  vim.keymap.set('n', '<Plug>setBuf', function() M.setBuf() end)
  vim.keymap.set('n', '<Plug>makeWin', function() M.makeWin("R", opts) end)
  vim.keymap.set('n', '<Plug>winSwitch', function() M.winSwitch() end)
  vim.keymap.set('n', '<Plug>closeWin', function() M.closeWin() end)

  vim.keymap.set('n', '<Plug>listSelect', function() M.listSelect(opts) end)
end
return M

--
-- need rto be able to go into the reference window to adjust the location or yank a chunk etc..
--

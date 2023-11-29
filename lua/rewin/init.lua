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
  local width = 40
  local color = vim.api.nvim_exec2('colo', { output = true })
  local bufnr = vim.api.nvim_create_buf(false, true)
  local cbuf = vim.fn.bufnr('%')


  local height = #data
  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = "cursor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = 'minimal',
    anchor = 'NW',
    border = { "▄", "▄", "▄", "█", "▀", "▀", "▀", "█" },
  })

  local groupId = vim.api.nvim_create_augroup('floatListGroup',{})

  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { command = "let g:haveWin='false'", group=groupId,buffer = bufnr })
  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { command = "let g:haveWin='false'", group=groupId,buffer = cbuf })
  vim.api.nvim_create_autocmd({ 'BufCreate','BufNew','CursorMoved' }, { command = "set winblend=30 | echo 'bufnr'", group=groupId,buffer = bufnr })
  vim.api.nvim_create_autocmd({ 'BufNew','BufCreate','CursorMoved' }, { command = "set winblend=30 | echo 'cbuf'", group=groupId,buffer = cbuf })
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    callback = function()
      vim.api.nvim_exec('set winblend=30',{})
      local line = vim.fn.line('.')
      local lineContent = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if vim.api.nvim_get_var('haveWin') == true then
        M.closeWin()
      end
      M.makeWin(lineContent, {})
      -- vim.api.nvim_cmd({cmd='set winblend=70'},{})
      vim.api.nvim_set_var('haveWin', true)
    end,
    buffer=bufnr
  })
  vim.keymap.set({ 'n', 'i' }, "<CR>", function() M.selectItem(bufnr) end, { buffer = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)

  return { win_id, bufnr }
end

M.selectItem = function(bufnr)
  local line = vim.fn.line('.')
  vim.api.nvim_win_close(0, true)
  vim.api.nvim_set_var('haveWin', true)
  vim.api.nvim_del_augroup_by_name('floatListGroup')
end


M.setBuf = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local ok = vim.api.nvim_buf_set_mark(0, 'R', line, 1, {})
  return true
end

-- get the mark and buffer to view in the window
local function getBuf(mark)
  local markLocation = vim.api.nvim_get_mark(tostring(mark), {}) -- row, col, buffer, bufferName
  local buffer = markLocation[3]
  vim.api.nvim_set_var('refBuf', buffer)
end

-- once window is open, enter or leave the window
M.winSwitch = function(opts)
  local gotRef = vim.api.nvim_eval('exists("g:refWin")')
  if gotRef == 0 then
    M.listSelect(opts)
    return
  end
  local win = vim.g.refWin
  if (vim.api.nvim_get_current_win() == win) then
    vim.api.nvim_set_current_win(vim.api.nvim_get_var('winSave'))
  elseif (win == nil) then
    M.MakeWin("R")
  else
    vim.api.nvim_set_var('winSave', vim.api.nvim_get_current_win())
    vim.api.nvim_set_current_win(win)
  end
end

M.closeWin = function()
  local win = vim.g.refWin
  if win == false then
    
  else
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_set_var('refWin', false)
    vim.api.nvim_set_var('haveWin', false)
  end
end

local function getResults()
  local marks = vim.api.nvim_exec2('marks', { output = true })
  -- local marks = vim.fn.getmarklist()

  local results = {}
  for m in string.gmatch(marks.output, "([^\r\n]+)") do
    local str = string.match(m, '^%s(%w)')
    if str then
      if string.len(str) > 1 then
      elseif string.match(str, "[0-9A-Z]") and vim.api.nvim_get_mark(str, {}) then
        table.insert(results, str)
      end
    end
  end
  return results
end

M.listSelect = function(opts)
  local data = getResults()
  local lineContent = M.floatingList(opts, data)
end


M.makeWin = function(mark, opts)
  if mark == "" then
    getBuf("R")
  else
    getBuf(mark)
  end


  local defaults = {
    relative = 'cursor',
    row = -2,
    col = 50,
    title = 'Reference',
    width = 80,
    height = 15,
    focusable = false,
    anchor = 'SW',
    border = 'none',
    style = 'minimal'
  }

  opts = vim.tbl_extend('keep', opts, defaults)
  if vim.api.nvim_get_var('haveWin') == true then
    M.closeWin()
    M.makeWin(mark, opts)
  end
  local buffer = vim.api.nvim_get_var('refBuf')
  local cbuf = vim.fn.bufnr('%')
  vim.api.nvim_create_augroup('madeWin',{})
  vim.api.nvim_create_autocmd({'WinNew'}, {command = "set winblend=45",group=madeWin,buffer=cbuf})
  vim.api.nvim_create_autocmd({'WinNew'}, {command = "set winblend=45",group=madeWin,buffer=buffer})
  vim.api.nvim_create_autocmd({ 'BufDelete' },
    { command = "let g:haveWin='false' | let g:refWin='false'", buffer = buffer })
  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { command = "let g:haveWin='false' | let g:refwin='false'", buffer = buffer })
  local win = vim.api.nvim_open_win(buffer, false,
    opts)
  vim.api.nvim_set_var('haveWin', true)
  vim.api.nvim_set_var('refWin', win)
  vim.api.nvim_del_augroup_by_name('madeWin')
  print('we set refWin in makeWin to: ', vim.g.refWin)
end

M.setup = function(opts)

  local defaults = {
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
  print('exists?', vim.api.nvim_eval('exists("g:haveWin")'))
  if vim.api.nvim_eval('exists("g:haveWin")') == 1 then
    if vim.g.haveWin == true then
      print('haveWin is true')
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


  -- if vim.g.haveWin == nil then
  --   vim.api.nvim_set_var('haveWin', false)
  -- elseif vim.g.haveWin == true then
  --   M.closeWin()
  --   print('lebuf',vim.g.refBuf)
  --   M.makeWin(vim.g.refBuf,{})
  -- end
  opts = vim.tbl_deep_extend('keep', opts, defaults)
  vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
  vim.keymap.set('n', '<leader>ww', function() M.makeWin("R", opts) end)
  vim.keymap.set('n', '<leader>we', function() M.winSwitch(opts) end)
  vim.keymap.set('n', '<leader>wc', function() M.closeWin() end)
  vim.keymap.set('n', '<leader>f', function() M.listSelect(opts) end)
end
M.setup({})
return M

--
-- need rto be able to go into the reference window to adjust the location or yank a chunk etc..
--

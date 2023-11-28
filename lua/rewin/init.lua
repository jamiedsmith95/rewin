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



M.floatingList = function(data)
  local width = 40
  print('data[1] in floating list', data[1])
  M.makeWin(data[1], {relative='editor', col = width + 10})


  local height = #data
  local bufnr = vim.api.nvim_create_buf(false, true)
  local win_id = vim.api.nvim_open_win(bufnr, true, {
    relative = "cursor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = "minimal",
    border = "none",
  })
  vim.keymap.set({ 'n', 'i' }, "<CR>", function() M.selectItem(bufnr) end, { buffer = bufnr })
  vim.keymap.set({ 'i', 'n' }, "<up>", function() M.move(bufnr, 'up') end, { buffer = bufnr })
  vim.keymap.set({ 'i', 'n' }, "<down>", function() M.move(bufnr, 'down') end, { buffer = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)

  return {win_id,bufnr}
  
end

M.move = function(bufnr, direction)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local height = vim.api.nvim_win_get_height(0)
  print('cursor in move',vim.inspect(cursor),'height ', vim.inspect(height))
  if direction == 'up' and cursor[1] >= 2  then
    vim.api.nvim_win_set_cursor(0, { cursor[1] - 1, cursor[2] })
  elseif direction == 'down' and cursor[1] < height then
    vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })
  end
  M.hoverOver(bufnr)
end

M.hoverOver = function(bufnr)
  local line = vim.fn.line('.')
  local lineContent = vim.api.nvim_buf_get_lines(bufnr, line-1,line, false)[1]
  print('line in hoverOver', line)
  if (vim.api.nvim_get_var('haveWin')) then
    M.closeWin()
  else

  end
  M.makeWin(tostring(lineContent), {relative = 'win', col = 5 + vim.api.nvim_win_get_width(0)})
end

M.selectItem = function(bufnr)
  local line = vim.fn.line('.')
  vim.api.nvim_win_close(0, true)
  local lineContent = vim.api.nvim_buf_get_lines(bufnr, line-1,line, false)[1]
  M.makeWin(tostring(lineContent),{relative = 'editor'})
  return lineContent
end


M.setBuf = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local ok = vim.api.nvim_buf_set_mark(0, 'R', line, 1, {})
  return true
end

-- get the mark and buffer to view in the window
local function getBuf(mark)
  print('getBuf mark', vim.inspect(mark))
  local markLocation = vim.api.nvim_get_mark(tostring(mark), {}) -- row, col, buffer, bufferName
  local buffer = markLocation[3]
  vim.api.nvim_set_var('refBuf', buffer)
end

-- once window is open, enter or leave the window
M.winToggle = function()
  local win = vim.api.nvim_get_var('refWin')
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
  local win = vim.api.nvim_get_var('refWin')
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_set_var('refWin', nil)
  vim.api.nvim_set_var('haveWin', false)
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

M.listSelect = function()
  local data = getResults()
  print('data listSelect', vim.inspect(data))
  print('data[0] listSelect', vim.inspect(data[1]))
  local lineContent = M.floatingList(data)
end

vim.api.nvim_set_var('haveWin', false)

M.makeWin = function(mark, opts)
  print('makeWin mark', mark)
  if mark == "" then
    getBuf("R")
  else
    getBuf(mark)
  end


  if vim.api.nvim_get_var('haveWin') then
    print('window already exists')
    M.closeWin()
    M.makeWin(mark,opts)
  else
    local defaults = {
      relative = 'editor',
      row = -2,
      col = 50,
      title = 'Reference',
      width = 80,
      height = 15,
      focusable = false,
      anchor =
      'SW',
      border = 'none'
    }

    opts = vim.tbl_extend('keep',opts,defaults)
    local buffer = vim.api.nvim_get_var('refBuf')
    local win = vim.api.nvim_open_win(buffer, false,
      opts)
    print('relative option = ', opts.relative)
    vim.api.nvim_set_var('haveWin', true)
    vim.api.nvim_set_var('refWin', win)
  end
end
vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
vim.keymap.set('n', '<leader>ww', function() M.MakeWin("R") end)
vim.keymap.set('n', '<leader>we', function() M.winToggle() end)
vim.keymap.set('n', '<leader>wc', function() M.closeWin() end)
vim.keymap.set('n', '<leader>tm', function() M.TeleMark({ {} }) end)
vim.keymap.set('n', '<leader>f', function() M.listSelect() end)

return M

--
-- need to be able to go into the reference window to adjust the location or yank a chunk etc..
--
-- neet to be able to leave the reference window

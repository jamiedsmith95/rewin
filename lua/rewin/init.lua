local conf = require("telescope.config").values
local action_state = require "telescope.actions.state"
local sorters = require "telescope.sorters"
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


local function onPrev(prompt_bufnr)
  actions.move_selection_previous(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  print(vim.inspect(entry))
  local markInfo = vim.api.nvim_get_mark(entry[1], {})
  -- vim.api.nvim_buf_set_mark(markInfo[3], 'R', markInfo[2], 0, {})
  if (vim.api.nvim_get_var("haveWin") == true) then
    M.closeWin()
  end
  M.MakeWin(entry[1])
end

local function onNext(prompt_bufnr)
  actions.move_selection_next(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  print(vim.inspect(entry))
  local markInfo = vim.api.nvim_get_mark(entry[1], {})
  -- vim.api.nvim_buf_set_mark(markInfo[3], 'R', markInfo[2], 0, {})
  if (vim.api.nvim_get_var("haveWin") == true) then
    M.closeWin()
  end
  M.MakeWin(entry{1})
end

local function onEnter(prompt_bufnr)
  if (vim.api.nvim_get_var("haveWin") == true) then
    M.closeWin()
  end
  local entry = action_state.get_selected_entry()
  print('ENTRY',vim.inspect(entry))
  local markInfo = vim.api.nvim_get_mark(entry[1], {})
  -- vim.api.nvim_buf_set_mark(markInfo[3], 'R', markInfo[2], 0, {})
  actions.close(prompt_bufnr)
  M.MakeWin(entry[1])
end




M.setBuf = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local ok = vim.api.nvim_buf_set_mark(0, 'R', line, 1, {})
  return true
end

-- get the mark and buffer to view in the window
local function getBuf(mark)
  print(vim.inspect(mark))
  local markLocation = vim.api.nvim_get_mark(mark, {}) -- row, col, buffer, bufferName
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
  print(win)
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_set_var('refWin', nil)
  vim.api.nvim_set_var('haveWin', false)
end

M.TeleMark = function(opts)
  local marks = vim.api.nvim_exec2('marks', { output = true })
  print(marks.output)

  local results = {}

  for m in string.gmatch(marks.output, "([^\r\n]+)") do
    local str = string.match(m, '^%s(%w)')
    print(str)
    if str then
      if string.len(str) > 1 then
        -- print('too long',str)
      elseif string.match(str, "[0-9A-Z]") and vim.api.nvim_get_mark(str, {}) then
        local b = {}
        local buf = vim.api.nvim_get_mark(str, {})
        b.mark = buf[1]
        b.row = buf[2]
        b.buffer = buf[3]
        b.bufferName = buf[4]

        -- table.insert(results,{str,buf[1],buf[3]})-- mark name, row, buffer
        table.insert(results, str) -- mark name, row, buffer
      else
        -- print('wrong format',str)
      end
    end
  end

  local opts = {
    finder = finders.new_table(results),
    sorter = require"telescope".generic_sorter,

    attach_mappings = function(prompt_bufnr, map)
      map("i", "<UP>, onNext")
      map("n", "<UP>, onNext")
      map("i", "<DOWN>, onPrev")
      map("n", "<DOWN>, onPrev")
      map("i", "<CR>", onEnter)
      map("n", "<CR>", onEnter)
      return true
    end
  }

  local marks = pickers.new(opts)
  marks:find()
end


vim.api.nvim_set_var('haveWin', false)

M.MakeWin = function(mark, opts)
  if mark == "" then
    getBuf("R")
  else
    getBuf(mark)
  end


  if vim.api.nvim_get_var('haveWin') then
    print('window already exists')
  else
    opts = opts or {}
    local defaults = {
      relative = 'cursor',
      row = -2,
      col = 1,
      title = 'Reference',
      width = 80,
      height = 15,
      focusable = false,
      anchor =
      'SW',
      border = 'none'
    }
    -- opts = vim.tbl_deep_extend(force, defaults, opts)
    local buffer = vim.api.nvim_get_var('refBuf')
    local win = vim.api.nvim_open_win(buffer, false,
      defaults)
    vim.api.nvim_set_var('haveWin', true)
    vim.api.nvim_set_var('refWin', win)
  end
end
vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
vim.keymap.set('n', '<leader>ww', function() M.MakeWin("R") end)
vim.keymap.set('n', '<leader>we', function() M.winToggle() end)
vim.keymap.set('n', '<leader>wc', function() M.closeWin() end)
vim.keymap.set('n', '<leader>tm', function() M.TeleMark({ {} }) end)
return M

--
-- need to be able to go into the reference window to adjust the location or yank a chunk etc..
--
-- neet to be able to leave the reference window

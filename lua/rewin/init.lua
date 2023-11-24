local M = {}

-- need the ability to find a file that you want to reference
-- or
-- need to be able to create a point within current buffer to reference later.

-- or just show list of marks, can make wrapper function if marks are not used much
-- neet to be able to create small floating window with the reference buffer at the point the reference was made

-- set a mark at location to reference
M.setBuf = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local ok = vim.api.nvim_buf_set_mark(0, 'R',line,1,{})
  return true

end

-- get the mark and buffer to view in the window
M.getBuf = function()
  local markLocation = vim.api.nvim_get_mark('R', {}) -- row, col, buffer, buffername
  local buffer = markLocation[3]
  vim.api.nvim_set_var('refBuf', buffer)
end

-- once window is open, enter or leave the window
M.winToggle = function()
  local win = vim.api.nvim_get_var('refWin')
  if(vim.api.nvim_get_current_win() == win) then
    vim.api.nvim_set_current_win(vim.api.nvim_get_var('winSave'))
  elseif (win == nil) then
    M.MakeWin()
  else
    vim.api.nvim_set_var('winSave',vim.api.nvim_get_current_win())
    vim.api.nvim_set_current_win(win)
  end
end

M.closeWin = function()
  local win = vim.api.nvim_get_var('refWin')
  vim.api.nvim_win_close(win,true)
  vim.api.nvim_set_var('refWin',nil)
  
end

M.MakeWin = function()
  M.getBuf()
  local buffer = vim.api.nvim_get_var('refBuf')

  local win = vim.api.nvim_open_win(buffer, false,
    { relative = 'cursor', row = -2, col = 20,title='Reference', width = 80, height = 15, focusable = false, anchor = 'SW',border='none' })
  vim.api.nvim_set_var('refWin',win)
end
vim.keymap.set('n', '<leader>sm', function() M.setBuf() end)
vim.keymap.set('n', '<leader>ww', function() print(vim.inspect(M.MakeWin())) end)
vim.keymap.set('n', '<leader>we', function() M.winToggle() end)
vim.keymap.set('n', '<leader>wc', function() M.closeWin() end)
return M

--
-- need to be able to go into the reference window to adjust the location or yank a chunk etc..
--
-- neet to be able to leave the reference window

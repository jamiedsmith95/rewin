local M = {}

-- need the ability to find a file that you want to reference
-- or
-- need to be able to create a point within current buffer to reference later.

-- or just show list of marks, can make wrapper function if marks are not used much
print('hello')
-- neet to be able to create small floating window with the reference buffer at the point the reference was made

M.getBuf = function()
  local markLocation = vim.api.nvim_get_mark() -- row, col, buffer, buffername
  local buffer = markLocation[3]
  return buffer
end


M.makeWin = function(buffer)
  vim.api.nvim_open_win(buffer, false,
    {relative='cursor', row=-3,col=4, width=20, height=11,focusable=true, anchor='SW', style='shadow' })

end
return M

--
-- need to be able to go into the reference window to adjust the location or yank a chunk etc..
--
-- neet to be able to leave the reference window

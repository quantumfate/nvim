local M = {}

M.level = vim.log.levels.WARN  -- Only show WARN and ERROR by default

function M.debug(msg) 
  if M.level <= vim.log.levels.DEBUG then
    vim.notify("[DEBUG] " .. msg, vim.log.levels.DEBUG)
  end
end

function M.error(msg)
  if M.level <= vim.log.levels.ERROR then
    vim.notify("[ERROR] " .. msg, vim.log.levels.ERROR)
  end
end

return M
--- Level-based logging over vim.notify.
---@class util.log
local M = {}

--- Mutable threshold: only messages at or above this level are shown.
---@type integer
M.level = vim.log.levels.WARN

--- Logs a debug message when the threshold allows it.
---@param msg string
function M.debug(msg)
	if M.level <= vim.log.levels.DEBUG then
		vim.notify("[DEBUG] " .. msg, vim.log.levels.DEBUG)
	end
end

--- Logs an error message when the threshold allows it.
---@param msg string
function M.error(msg)
	if M.level <= vim.log.levels.ERROR then
		vim.notify("[ERROR] " .. msg, vim.log.levels.ERROR)
	end
end

return M

--- Logging utility module for structured debug and error messages
--- Provides level-based logging with configurable verbosity
---@class util.log
local M = {}

--- Current logging level threshold (only messages at or above this level are shown)
---@type integer
M.level = vim.log.levels.WARN -- Only show WARN and ERROR by default

--- Log a debug message if debug level is enabled
--- Only displays if current log level is DEBUG or lower
---@param msg string The debug message to log
function M.debug(msg)
	if M.level <= vim.log.levels.DEBUG then
		vim.notify("[DEBUG] " .. msg, vim.log.levels.DEBUG)
	end
end

--- Log an error message if error level is enabled
--- Only displays if current log level is ERROR or lower
---@param msg string The error message to log
function M.error(msg)
	if M.level <= vim.log.levels.ERROR then
		vim.notify("[ERROR] " .. msg, vim.log.levels.ERROR)
	end
end

return M

--- Toolchain events to the desktop and to toolchain-events.jsonl. Shared schema with
--- the ansible role's notifier, so one log covers both.
---@class toolchain.notify
local M = {}

---@class toolchain.Event
---@field status "ok"|"failed"
---@field phase string What was being done: "update", "packages", "plugins", ...
---@field ecosystem? string
---@field tool? string
---@field exit? integer
---@field detail? string
---@field source? string Defaults to "nvim"

---@return string
function M.log_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "toolchain-events.jsonl")
end

---@param event toolchain.Event
local function append(event)
	local path = M.log_path()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local fd = vim.uv.fs_open(path, "a", 420) -- 0644
	if not fd then
		return
	end
	vim.uv.fs_write(fd, vim.json.encode(event) .. "\n")
	vim.uv.fs_close(fd)
end

---@param event toolchain.Event
local function desktop(event)
	if vim.fn.executable("notify-send") == 0 then
		return
	end
	local failed = event.status == "failed"
	local subject = event.tool or event.ecosystem or event.phase
	vim.system({
		"notify-send",
		"--app-name=nvim-toolchain",
		"--urgency=" .. (failed and "critical" or "low"),
		"--category=nvim.toolchain." .. event.status,
		"--icon=" .. (failed and "dialog-error" or "dialog-information"),
		"--hint=string:x-nvim-status:" .. event.status,
		"--hint=string:x-nvim-phase:" .. event.phase,
		"--hint=string:x-nvim-ecosystem:" .. (event.ecosystem or ""),
		"--hint=string:x-nvim-tool:" .. (event.tool or ""),
		"--hint=int:x-nvim-exit:" .. tostring(event.exit or 0),
		"--hint=string:x-nvim-timestamp:" .. event.timestamp,
		"--hint=string:x-nvim-log:" .. M.log_path(),
		"--hint=string:x-nvim-store:" .. require("toolchain.store").path(),
		("neovim toolchain: %s %s"):format(subject, failed and "failed" or "ok"),
		event.detail or "",
	}, { detach = true })
end

---@param event toolchain.Event
function M.event(event)
	event.source = event.source or "nvim"
	event.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
	event.host = vim.uv.os_gethostname()
	vim.schedule(function()
		append(event)
		desktop(event)
	end)
end

return M

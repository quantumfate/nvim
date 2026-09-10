--- What is running in the background, and how long it has been running.
---
--- `vim.system` is genuinely asynchronous, which is the point — a `cargo rustc` for the
--- assembly view takes seconds and the editor stays usable throughout. The cost is that
--- nothing on screen says so, and a slow compile is indistinguishable from a keypress
--- that did not register.
---
--- So every background command registers here, and the statusline shows a spinner for
--- as long as one is outstanding.
---@class lang.jobs
local M = {}

---@class lang.Job
---@field title string
---@field cmd string
---@field started integer Nanoseconds, from vim.uv.hrtime

---@type table<integer, lang.Job>
local running = {}
local next_id = 0

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Registers a job. The returned function marks it finished.
---@param title string
---@param cmd string
---@return fun()
function M.start(title, cmd)
	next_id = next_id + 1
	local id = next_id
	running[id] = { title = title, cmd = cmd, started = vim.uv.hrtime() }

	-- lualine renders on its own timer (a second, by default) and caches between
	-- ticks, so `:redrawstatus` repaints the cached string and the spinner sits on one
	-- frame. `lualine.refresh` is what actually re-evaluates the components.
	local timer = assert(vim.uv.new_timer())
	timer:start(0, 120, function()
		if running[id] then
			vim.schedule(function()
				local ok, lualine = pcall(require, "lualine")
				if ok then
					pcall(lualine.refresh, { place = { "statusline" } })
				else
					pcall(vim.cmd.redrawstatus)
				end
			end)
		else
			timer:stop()
			if not timer:is_closing() then
				timer:close()
			end
			-- One last refresh so the spinner clears instead of freezing on its final
			-- frame until something else happens to repaint.
			vim.schedule(function()
				local ok, lualine = pcall(require, "lualine")
				if ok then
					pcall(lualine.refresh, { place = { "statusline" } })
				end
			end)
		end
	end)

	return function()
		running[id] = nil
	end
end

--- True when a job with this title is already in flight.
---@param title string
---@return boolean
function M.running(title)
	for _, job in pairs(running) do
		if job.title == title then
			return true
		end
	end
	return false
end

--- True while anything is running.
---@return boolean
function M.active()
	return next(running) ~= nil
end

--- Spinner, title and elapsed seconds for the statusline, or an empty string.
---@return string
function M.status()
	local id, job = next(running)
	if not job then
		return ""
	end

	local count = 0
	for _ in pairs(running) do
		count = count + 1
	end

	local frame = SPINNER[math.floor(vim.uv.hrtime() / (1e6 * 100)) % #SPINNER + 1]
	local seconds = math.floor((vim.uv.hrtime() - job.started) / 1e9)

	-- Seconds only once it is slow enough to wonder about. A number that starts at 0
	-- on every keypress is noise.
	local elapsed = seconds >= 2 and (" %ds"):format(seconds) or ""
	local extra = count > 1 and (" +%d"):format(count - 1) or ""
	return ("%s %s%s%s"):format(frame, job.title, elapsed, extra)
end

--- Everything currently running, for `:LangJobs`.
---@return string[]
function M.report()
	local out = {}
	for _, job in pairs(running) do
		table.insert(out, ("  %-28s %s  (%.1fs)"):format(job.title, job.cmd, (vim.uv.hrtime() - job.started) / 1e9))
	end
	return #out > 0 and out or { "  nothing running" }
end

return M

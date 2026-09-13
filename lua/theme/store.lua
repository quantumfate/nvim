--- Follows the desktop's shared theme store so the editor's colorscheme tracks the
--- system palette live, with no restart.
---
--- The store ($XDG_STATE_HOME/theme.json) is written elsewhere (Quickshell, Hyprland,
--- ,theme.sh) and read by every desktop surface; this module is nvim's reader. It is
--- watched rather than polled, and applied through the same theme.set() a user would
--- call by hand, so a store-driven change is indistinguishable from a manual one once
--- it lands.
---@class theme.store
local M = {}

--- palette (this file's vocabulary) -> colorscheme name (theme.themes' vocabulary).
--- The desktop only ever names a Catppuccin flavour; if it grows a flavour this
--- config's catppuccin doesn't ship, that entry is simply absent and gets ignored.
---@type table<string, string>
local PALETTES = {
	latte = "catppuccin-latte",
	frappe = "catppuccin-frappe",
	macchiato = "catppuccin-macchiato",
	mocha = "catppuccin-mocha",
}

--- Where the desktop keeps the shared theme, honoring the same override the other
--- consumers do.
---@return string
local function path()
	local root = os.getenv("XDG_STATE_HOME") or vim.fs.joinpath(vim.env.HOME, ".local", "state")
	return vim.fs.joinpath(root, "theme.json")
end

--- Reads the store and maps it to a colorscheme name. Never throws: a missing file,
--- unreadable file, malformed JSON, or a palette this config has no mapping for all
--- come back as nil so the caller can just leave the editor alone.
---@return string|nil
function M.read()
	local ok_read, lines = pcall(vim.fn.readfile, path())
	if not ok_read or #lines == 0 then
		return nil
	end
	local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok_decode or type(decoded) ~= "table" then
		return nil
	end
	return PALETTES[decoded.palette]
end

--- Set once setup() has installed the watcher, so tests and :Theme can tell it apart
--- from an ordinary call.
local watching = false

--- Applies the store's current palette, unless a manual :Theme call has taken this
--- session out of following it (see theme.lua's `manual` flag).
local function apply()
	if require("theme").manual() then
		return
	end
	local colorscheme = M.read()
	if colorscheme and colorscheme ~= vim.g.colors_name then
		require("theme").set(colorscheme, { persist = false })
	end
end

local debounce = nil ---@type uv.uv_timer_t?

--- Watches the store's directory (not the file) for changes and applies them live.
---
--- The file is replaced by an atomic rename on every write, which swaps the inode
--- out from under a watch on the file itself — libuv fires once for that first
--- rename and then watches a now-orphaned inode nothing writes to again. Watching
--- the containing directory sidesteps this: renames into it keep re-arming.
function M.setup()
	if watching then
		return
	end
	watching = true

	-- Deferred: setup() runs from theme.setup(), which core/init.lua calls while
	-- lazy.nvim is still registering plugins. Loading one synchronously here would
	-- reenter lazy's own setup.
	vim.schedule(apply)

	local dir = vim.fs.dirname(path())
	local handle = vim.uv.new_fs_event()
	if not handle or vim.uv.fs_stat(dir) == nil then
		return
	end

	local ok = handle:start(dir, {}, function(err, filename)
		if err or filename ~= "theme.json" then
			return
		end
		if debounce then
			debounce:stop()
		else
			debounce = assert(vim.uv.new_timer())
		end
		debounce:start(100, 0, function()
			vim.schedule(apply)
		end)
	end)
	if not ok then
		handle:close()
	end
end

return M

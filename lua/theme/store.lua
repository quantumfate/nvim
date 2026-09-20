--- Follows the desktop's shared theme store so the editor's colorscheme tracks the
--- system palette live, with no restart.
---
--- The store ($XDG_STATE_HOME/theme.json) is written elsewhere (Quickshell, Hyprland,
--- ,theme.sh) and read by every desktop surface; this module is nvim's reader. It is
--- watched rather than polled, and applied through the same theme.set() a user would
--- call by hand, so a store-driven change is indistinguishable from a manual one once
--- it lands.
---
--- The store keeps the *baseline* palette (`palette`) and the palette in effect right
--- now (`resolved`): a mode holds a lease the way it holds a window, and while it does
--- the lease's palette is what is actually shown. This editor cannot run the desk's
--- lease resolver, so ,theme.sh writes `resolved` for it — the same value its socket
--- pokes use — and the editor follows that single authority, falling back to
--- `palette` on stores written before the field existed (they are equal with no lease
--- held).
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

--- Where the desktop keeps the shared theme: the shared quantum-store
--- directory ($QF_STORE), matching the other consumers, with the legacy
--- path as the one step back.
---@return string
local function path()
	local env = os.getenv("QF_STORE")
	local root = env
		or vim.fs.joinpath(
			os.getenv("XDG_STATE_HOME") or vim.fs.joinpath(vim.env.HOME, ".local", "state"),
			"quantum-store"
		)
	local file = vim.fs.joinpath(root, "theme.json")
	if vim.uv.fs_stat(file) == nil then
		local legacy = vim.fs.joinpath(
			os.getenv("XDG_STATE_HOME") or vim.fs.joinpath(vim.env.HOME, ".local", "state"),
			"theme.json"
		)
		if vim.uv.fs_stat(legacy) ~= nil then
			return legacy
		end
	end
	return file
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
	-- `resolved` is the single authority, written by ,theme.sh apply on every pass
	-- as the lease-aware palette its socket pokes use; `palette` is the baseline it
	-- is also written beside. Older stores have only `palette`, and with no lease
	-- held the two are equal anyway.
	return PALETTES[decoded.resolved or decoded.palette]
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
---
---@param dir? string Directory to watch instead of the store's own (a scratch
--- store's directory, for tests arming the watcher independently).
function M.setup(dir)
	if dir == nil and watching then
		return
	end
	watching = true

	-- Deferred: setup() runs from theme.setup(), which core/init.lua calls while
	-- lazy.nvim is still registering plugins. Loading one synchronously here would
	-- reenter lazy's own setup.
	vim.schedule(apply)

	local target = dir or vim.fs.dirname(path())
	local handle = vim.uv.new_fs_event()
	if not handle or vim.uv.fs_stat(target) == nil then
		return
	end

	local ok = handle:start(target, {}, function(err, filename)
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

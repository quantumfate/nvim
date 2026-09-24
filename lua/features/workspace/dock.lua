--- The bottom slot, and the one thing that lives in it at a time.
---
--- Six things want the bottom edge — a terminal, the debugger, the debuggee's output,
--- diagnostics, quickfix, test output — and edgy will happily stack all of them. The
--- result is a crowded strip where you hunt for the one you meant.
---
--- So the dock holds exactly one view. Opening another puts the current one away and
--- remembers it, which makes `q` and `<leader>wd` mean "back to what I had" rather
--- than "close everything and start again".
---
--- This replaces a `solo` flag that expanded to `:only` — closing every window in the
--- tab, editor panes included, to make room for a panel at the bottom.
---@class workspace.dock
local M = {}

---@class workspace.DockView
---@field title string
---@field open string|fun() Command or function that opens it
---@field close string|fun() Command or function that closes it
---@field ft string|string[] Filetype(s) its window carries, for detecting it

--- Everything that may occupy the dock. A view not listed here is not managed, and
--- opens wherever it likes — which is fine, it just does not participate.
---@type table<string, workspace.DockView>
M.views = {
	terminal = {
		title = "Terminal",
		ft = "snacks_terminal",
		open = function()
			-- `Snacks.terminal()` reuses the terminal for this cwd, so the shell and its
			-- scrollback survive being hidden and shown again.
			Snacks.terminal()
		end,
		close = function()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "snacks_terminal" and vim.api.nvim_win_is_valid(win) then
					pcall(vim.api.nvim_win_close, win, false)
				end
			end
		end,
	},
	debug = {
		title = "Debug",
		ft = { "dap-view", "dap-view-term" },
		open = "DapViewOpen",
		close = "DapViewClose",
	},
	-- `open_no_results=true` matters: without it a clean buffer opens nothing at all,
	-- and the key reads as broken rather than as "no diagnostics". `focus=false` keeps
	-- the cursor in the code. `filter.buf=0` scopes it to this file.
	diagnostics = {
		title = "Diagnostics",
		ft = "trouble",
		open = "Trouble diagnostics open filter.buf=0 focus=false open_no_results=true",
		close = "Trouble diagnostics close",
	},

	loclist = {
		title = "Loclist",
		ft = "trouble",
		open = "Trouble loclist open filter.buf=0 focus=false open_no_results=true",
		close = "Trouble loclist close",
	},

	symbols = {
		title = "Symbols",
		ft = "symbols",
		open = "Trouble symbols open filter.buf=0 focus=false open_no_results=true",
		close = "Trouble symbols close",
	},

	todo = {
		title = "Todos",
		ft = "todo",
		open = "Trouble todo open filter.buf=0 focus=false open_no_results=true",
		close = "Trouble todo close",
	},

	-- Every file, not just this one. Servers that can report on files you have not
	-- opened (workspace/diagnostic) are asked to; for Lua and C, whose servers cannot,
	-- a batch check runs in the background and its findings join the list as they land.
	project = {
		title = "Project Diagnostics",
		ft = "trouble",
		open = function()
			local project_check = require("features.workspace.project_check")
			project_check.setup()
			project_check.run(vim.api.nvim_get_current_buf())
			for _, client in ipairs(vim.lsp.get_clients()) do
				if client:supports_method("workspace/diagnostic") then
					pcall(vim.lsp.buf.workspace_diagnostics, { client_id = client.id })
				end
			end
			vim.cmd("Trouble diagnostics open focus=false open_no_results=true")
		end,
		close = "Trouble diagnostics close",
	},
	quickfix = {
		title = "QuickFix",
		ft = "trouble",
		open = "Trouble qflist open focus=false open_no_results=true",
		close = "Trouble qflist close",
	},
	tests = {
		title = "Test Output",
		ft = "neotest-output-panel",
		open = "Neotest output-panel open",
		close = "Neotest output-panel close",
	},
}

--- What is in the dock now, and what was in it before.
---@type { current: string?, previous: string? }
local state = { current = nil, previous = nil }

---@param action string|fun()
local function run(action)
	if type(action) == "string" then
		pcall(vim.api.nvim_command, action)
	else
		pcall(action)
	end
end

--- Closes every managed view except `keep`.
---@param keep? string
local function close_others(keep)
	for name, view in pairs(M.views) do
		if name ~= keep then
			run(view.close)
		end
	end
end

--- True when the named view currently has a window.
---@param name string
---@return boolean
function M.is_open(name)
	local view = M.views[name]
	if not view then
		return false
	end
	local ft_val = view.ft
	local fts = type(ft_val) == "table" and ft_val or { ft_val }
	---@cast fts string[]
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
			if vim.tbl_contains(fts, ft) then
				return true
			end
		end
	end
	return false
end

--- Forgets an occupant whose window is gone.
---
--- `q` closes a docked panel, and so does edgy, and neither says so. A remembered
--- occupant then makes `<leader>wd` close nothing and `<leader>wb` refuse.
---@return string? current
local function reconcile()
	if state.current and not M.is_open(state.current) then
		state.previous = state.current
		state.current = nil
	end
	return state.current
end
--- Puts `name` in the dock, remembering what it displaced.
---@param name string
function M.open(name)
	local view = M.views[name]
	if not view then
		Snacks.notify.error("Unknown dock view: " .. name, { title = "Workspace" })
		return
	end

	local current = reconcile()
	if current and current ~= name then
		state.previous = current
	end

	-- The editor panes are never touched. Only the other dock occupants make way,
	-- which is the whole difference from the `:only` this replaces.
	close_others(name)
	run(view.open)
	state.current = name

	-- edgy re-lays the bottom edge after the window appears; equalising once it has
	-- settled keeps the editor panes the size they were.
	vim.defer_fn(function()
		pcall(vim.cmd --[[@as function]], "wincmd =")
	end, 120)
end

--- Empties the dock.
function M.close()
	close_others(nil)
	state.previous = state.current
	state.current = nil
end

--- Shows `name`, or closes the dock when it is already showing.
---
--- One key per view, and that key does the whole job: press it to bring the view up,
--- press it again to put the dock away, press a different one to swap. Nothing to
--- remember about which key closes what.
---@param name? string
function M.toggle(name)
	local current = reconcile()
	name = name or current or state.previous or "terminal"
	if current == name then
		M.close()
	else
		M.open(name)
	end
end

--- Swaps back to whatever was in the dock before the current occupant.
function M.back()
	reconcile()
	if not state.previous then
		Snacks.notify.info("Nothing to go back to", { title = "Workspace" })
		return
	end
	M.open(state.previous)
end

--- Name of the current occupant, for the statusline.
---@return string?
function M.current()
	local name = reconcile()
	return name and M.views[name] and M.views[name].title or nil
end

return M

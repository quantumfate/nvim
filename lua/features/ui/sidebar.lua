--- Mutually exclusive left sidebar explorer managing filesystem, buffers, and git status.
--- Guarantees only one active explorer occupies the left edge, eliminating collapsed window traps.
---@class ui.sidebar
local M = {}

local Slot = require("features.ui.slot")

M.SOURCES = { "filesystem", "buffers", "git_status" }
M.LABELS = {
	filesystem = "Files",
	buffers = "Buffers",
	git_status = "Git",
}
M.ICONS = {
	filesystem = " ",
	buffers = " ",
	git_status = " ",
}

M.slot = Slot.new("sidebar")

--- Root directory for the explorer.
---@return string
local function get_root()
	return require("lib.root").get()
end

--- Closes any open neo-tree window directly.
local function close_neotree()
	pcall(vim.cmd --[[@as function]], "Neotree close")
end

-- Register views in the sidebar slot
for _, source in ipairs(M.SOURCES) do
	M.slot:register(source, {
		title = "Sidebar " .. M.LABELS[source],
		ft = "neo-tree",
		open = function()
			-- In neo-tree v3, Neotree show position=left replaces the source in the existing window
			local cmd = ("Neotree show position=left %s dir=%s"):format(source, get_root())
			pcall(vim.cmd --[[@as function]], cmd)
		end,
		close = close_neotree,
		on_enter = function(win, buf)
			M.attach_keymaps(win, buf)
		end,
	})
end

--- Attaches buffer-local navigation keymaps to switch sidebar views.
---@param win integer
---@param buf integer
function M.attach_keymaps(win, buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local opts = { buffer = buf, silent = true, nowait = true }

	-- Tab / S-Tab cycles between sources inside the sidebar window
	vim.keymap.set("n", "<Tab>", function()
		M.cycle(1)
	end, vim.tbl_extend("force", opts, { desc = "Next sidebar view" }))

	vim.keymap.set("n", "<S-Tab>", function()
		M.cycle(-1)
	end, vim.tbl_extend("force", opts, { desc = "Previous sidebar view" }))

	-- Direct view switches from within the sidebar
	vim.keymap.set("n", "1", function()
		M.switch("filesystem")
	end, vim.tbl_extend("force", opts, { desc = "Switch to Files" }))

	vim.keymap.set("n", "2", function()
		M.switch("buffers")
	end, vim.tbl_extend("force", opts, { desc = "Switch to Buffers" }))

	vim.keymap.set("n", "3", function()
		M.switch("git_status")
	end, vim.tbl_extend("force", opts, { desc = "Switch to Git" }))
end

--- Switches the active sidebar view, replacing the current one in-place.
---@param source "filesystem"|"buffers"|"git_status"
function M.switch(source)
	M.slot:open(source)
end

--- Toggles the specified sidebar source.
---@param source? "filesystem"|"buffers"|"git_status"
function M.toggle(source)
	source = source or "filesystem"
	M.slot:toggle(source)
end

--- Cycles to next or previous source in the vertical array.
---@param direction 1|-1
function M.cycle(direction)
	local cur = M.active_source() or "filesystem"
	local cur_idx = 1
	for idx, s in ipairs(M.SOURCES) do
		if s == cur then
			cur_idx = idx
			break
		end
	end
	local next_idx = cur_idx + direction
	if next_idx > #M.SOURCES then
		next_idx = 1
	elseif next_idx < 1 then
		next_idx = #M.SOURCES
	end
	M.switch(M.SOURCES[next_idx])
end

--- Gets the currently active source name.
---@return string?
function M.active_source()
	local name = M.slot:find_open()
	return name or M.slot.active_name
end

--- Returns true when the sidebar is currently open.
---@return boolean
function M.is_open()
	local _, win = M.slot:find_open()
	return win ~= nil
end

--- Focuses the sidebar window.
---@return boolean focused
function M.focus()
	return M.slot:focus()
end

--- Returns formatted vertical selector representation for the other available views.
---@return { label: string, source: string, icon: string }[]
function M.available_views()
	local active = M.active_source() or "filesystem"
	local other = {}
	for _, s in ipairs(M.SOURCES) do
		if s ~= active then
			table.insert(other, {
				source = s,
				label = M.LABELS[s],
				icon = M.ICONS[s],
			})
		end
	end
	return other
end

return M

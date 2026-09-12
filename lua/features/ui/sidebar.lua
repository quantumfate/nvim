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
	})
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

--- Catppuccin's answer to the role contract.
---
--- Every field here is a correction to what theme.roles could work out on its own, and
--- nothing more: without this file catppuccin still themes correctly, it just guesses
--- blue for the accent (Function's colour) and interpolates the ramp instead of using
--- the surface/overlay steps catppuccin already ships.
---@class theme.adapter
---@field colorscheme? string Name to pass to :colorscheme, when it differs from the adapter file
---@field roles? fun(derived: theme.Roles): table Partial roles merged over the derived ones
local M = {}

--- Catppuccin registers one colorscheme name per flavour.
M.colorscheme = "catppuccin"

--- @param _ theme.Roles The derived roles, unused: catppuccin publishes its palette
---@return table Partial roles, merged over the derived ones
function M.roles(_)
	local ok, palettes = pcall(require, "catppuccin.palettes")
	if not ok then
		return {}
	end
	local p = palettes.get_palette()
	if not p then
		return {}
	end

	local function rgb(hex)
		return tonumber(hex:gsub("#", ""), 16)
	end

	return {
		-- The ramp catppuccin is built around, in its own order.
		ramp = {
			rgb(p.base),
			rgb(p.surface0),
			rgb(p.surface1),
			rgb(p.surface2),
			rgb(p.overlay0),
			rgb(p.overlay1),
			rgb(p.subtext0),
			rgb(p.text),
		},
		-- Reserved for the one active thing on screen, which is why it is not taken
		-- from Function: syntax colour is not accent colour.
		accent = rgb(p.mauve),
		ok = rgb(p.green),
		warn = rgb(p.yellow),
		err = rgb(p.red),
		info = rgb(p.blue),
		hint = rgb(p.teal),
		changed = rgb(p.peach),
	}
end

return M

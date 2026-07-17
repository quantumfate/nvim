--- Per-mode lualine colors from the Catppuccin Macchiato palette.
---@class util.plugins.lualine.color
-- C / O: pulled from the active catppuccin theme; drives every colour below.
local C = require("catppuccin.palettes").get_palette("macchiato")
local O = require("catppuccin").options
local transparent_bg = O.transparent_background and "NONE" or C.mantle

---@type table<string, {a: table, b: table, c: table, x: table, y: table, z: table}>
return {
	normal = {
		a = { bg = C.mauve, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.mauve },
		c = { bg = transparent_bg, fg = C.mauve },
		x = { bg = transparent_bg, fg = C.mauve },
		y = { bg = C.surface0, fg = C.mauve },
		z = { bg = C.mauve, fg = C.mantle, gui = "bold" },
	},

	insert = {
		a = { bg = C.peach, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.peach },
		c = { bg = transparent_bg, fg = C.peach },
		x = { bg = transparent_bg, fg = C.peach },
		y = { bg = C.surface0, fg = C.peach },
		z = { bg = C.peach, fg = C.mantle, gui = "bold" },
	},

	terminal = {
		a = { bg = C.green, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.green },
		c = { bg = transparent_bg, fg = C.green },
		x = { bg = transparent_bg, fg = C.green },
		y = { bg = C.surface0, fg = C.green },
		z = { bg = C.green, fg = C.mantle, gui = "bold" },
	},

	command = {
		a = { bg = C.red, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.red },
		c = { bg = transparent_bg, fg = C.red },
		x = { bg = transparent_bg, fg = C.red },
		y = { bg = C.surface0, fg = C.red },
		z = { bg = C.red, fg = C.mantle, gui = "bold" },
	},
	visual = {
		a = { bg = C.lavender, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.lavender },
		c = { bg = transparent_bg, fg = C.lavender },
		x = { bg = transparent_bg, fg = C.lavender },
		y = { bg = C.surface0, fg = C.lavender },
		z = { bg = C.lavender, fg = C.mantle, gui = "bold" },
	},
	replace = {
		a = { bg = C.flamingo, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.flamingo },
		c = { bg = transparent_bg, fg = C.flamingo },
		x = { bg = transparent_bg, fg = C.flamingo },
		y = { bg = C.surface0, fg = C.flamingo },
		z = { bg = C.flamingo, fg = C.mantle, gui = "bold" },
	},
	inactive = {
		a = { bg = C.mauve, fg = C.mantle, gui = "bold" },
		b = { bg = C.surface0, fg = C.mauve },
		c = { bg = transparent_bg, fg = C.mauve },
		x = { bg = transparent_bg, fg = C.mauve },
		y = { bg = C.surface0, fg = C.mauve },
		z = { bg = C.mauve, fg = C.mantle, gui = "bold" },
	},
}

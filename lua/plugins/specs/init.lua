local module_string = "plugins.specs."

local catppuccin = require(module_string .. "catppuccin")
local bufferline = require(module_string .. "bufferline")

print(vim.inspect(bufferline))
return {
	catppuccin,
	bufferline
}

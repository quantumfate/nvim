local plugins = {
	"catppuccin",
	"bufferline",
	"lualine",
	"nvim-navic",
}

local specs = {}
for _, plugin in ipairs(plugins) do
	specs[#specs + 1] = require("plugins.specs." .. plugin)
end

return specs
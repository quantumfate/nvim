_G.icons = require("util.icons")
_G.mini_icons_mt = setmetatable({}, {
	__index = function(t, k)
		if type(k) ~= "string" then
			return nil
		end
		local icons_module = require("mini.icons")
		local key_lower = k:lower()
		local status_ok, icon = pcall(icons_module.get, "lsp", key_lower)
		if status_ok and icon then
			local result = icon .. " "
			rawset(t, k, result)
			return result
		end
		return nil
	end,
})

require("config.settings")
require("config.autocmds")

return {
	"nvim-mini/mini.icons",
	lazy = true,
	opts = {
		file = {
			[".keep"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
			["devcontainer.json"] = { glyph = "", hl = "MiniIconsAzure" },
		},
		filetype = {
			dotenv = { glyph = "", hl = "MiniIconsYellow" },
		},
	},
	init = function()
		package.preload["nvim-web-devicons"] = function()
			require("mini.icons").mock_nvim_web_devicons()
			return package.loaded["nvim-web-devicons"]
		end
		vim.schedule(function()
			require("mini.icons").tweak_lsp_kind("prepend") -- or "append" or "replace"
		end)
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
	end,
}

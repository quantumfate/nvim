-- mini.icons spec: custom glyphs, nvim-web-devicons shim, and a lazy LSP-kind icon lookup table.

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
	--- Shims nvim-web-devicons onto mini.icons and exposes a lazily-built LSP-kind icon map.
	---@return nil
	init = function()
		-- Make any `require("nvim-web-devicons")` resolve to mini.icons' mock.
		package.preload["nvim-web-devicons"] = function()
			require("mini.icons").mock_nvim_web_devicons()
			return package.loaded["nvim-web-devicons"]
		end
		vim.schedule(function()
			require("mini.icons").tweak_lsp_kind("prepend")
		end)

		-- External global: _G.mini_icons_mt maps an LSP-kind name to its glyph, memoizing on first access.
		_G.mini_icons_mt = setmetatable({}, {
			__index = function(cache, kind)
				if type(kind) ~= "string" then
					return nil
				end
				local ok, icon = pcall(require("mini.icons").get, "lsp", kind:lower())
				if ok and icon then
					local glyph = icon .. " "
					rawset(cache, kind, glyph)
					return glyph
				end
				return nil
			end,
		})
	end,
}

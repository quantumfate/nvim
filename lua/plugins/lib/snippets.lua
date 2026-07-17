-- LuaSnip spec: loads bundled and config snippets and extends filetypes with doc-comment snippets.

return {
	{
		"L3MON4D3/LuaSnip",
		build = "make install_jsregexp",
		lazy = true,
		dependencies = {
			{
				"rafamadriz/friendly-snippets",
				--- Loads VSCode-format snippets from the bundle and the user config dir.
				---@return nil
				config = function()
					require("luasnip.loaders.from_vscode").lazy_load()
					require("luasnip.loaders.from_vscode").lazy_load({
						paths = { vim.fn.stdpath("config") .. "/snippets" },
					})
				end,
			},
			"benfowler/telescope-luasnip.nvim",
		},
		--- Sets up LuaSnip, lazy-loads every loader format, and maps filetypes to doc snippets.
		---@param opts table|nil
		---@return nil
		config = function(_, opts)
			local luasnip = require("luasnip")

			if opts then
				luasnip.config.setup(opts)
			end

			vim.tbl_map(function(type)
				require("luasnip.loaders.from_" .. type).lazy_load()
			end, { "vscode", "snipmate", "lua" })

			-- Attach per-language doc/comment snippet sets.
			local extend = luasnip.filetype_extend
			extend("typescript", { "tsdoc" })
			extend("javascript", { "jsdoc" })
			extend("lua", { "luadoc" })
			extend("python", { "pydoc", "debug", "unittest", "comprehension" })
			extend("rust", { "rustdoc" })
			extend("c", { "cdoc" })
			extend("cpp", { "cppdoc" })
			extend("sh", { "shelldoc" })
			extend("cs", { "csharpdoc" })
			extend("java", { "javadoc" })
			extend("php", { "phpdoc" })
			extend("kotlin", { "kdoc" })
			extend("ruby", { "rdoc" })
			extend("markdown", { "jekyll" })
		end,
	},
}

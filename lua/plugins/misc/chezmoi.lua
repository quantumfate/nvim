return {
	{
		"xvzc/chezmoi.nvim",
		cmd = { "ChezmoiEdit" },
		keys = {
			{
				"<leader>sz",
				require("util.plugins.chezmoi").pick_chezmoi,
				desc = "Chezmoi",
			},
		},
		opts = {
			edit = {
				watch = false,
				force = false,
				ignore_patterns = {
					"run_onchange_.*",
					"run_once_.*",
					"%.chezmoiignore",
					"%.chezmoitemplate",
					"%.sh.tmpl",
					"%.tmpl",
				},
			},
			notification = {
				on_open = true,
				on_apply = true,
				on_watch = false,
			},
			telescope = {
				select = { "<CR>" },
			},
		},
		init = function()
			-- run chezmoi edit on file enter
			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				pattern = { vim.env.HOME .. "/.local/share/chezmoi/*" },
				callback = function()
					vim.schedule(require("chezmoi.commands.__edit").watch)
				end,
			})
		end,
	},
	{
		"nvim-mini/mini.icons",
		opts = {
			file = {
				[".chezmoiignore"] = { glyph = "", hl = "MiniIconsGrey" },
				[".chezmoiremove"] = { glyph = "", hl = "MiniIconsGrey" },
				[".chezmoiroot"] = { glyph = "", hl = "MiniIconsGrey" },
				[".chezmoiversion"] = { glyph = "", hl = "MiniIconsGrey" },
				["bash.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
				["json.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
				["ps1.tmpl"] = { glyph = "󰨊", hl = "MiniIconsGrey" },
				["sh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
				["toml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
				["yaml.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
				["zsh.tmpl"] = { glyph = "", hl = "MiniIconsGrey" },
			},
		},
	},
}

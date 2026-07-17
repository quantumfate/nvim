-- chezmoi spec: edit-in-place integration for the chezmoi source dir, plus mini.icons glyphs.

return {
	{
		"xvzc/chezmoi.nvim",
		cmd = { "ChezmoiEdit" },
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
					"%.sh",
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
		--- Starts chezmoi's edit watcher when opening a file inside the chezmoi source dir.
		---@return nil
		init = function()
			-- External: vim.env.HOME locates the chezmoi source directory.
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

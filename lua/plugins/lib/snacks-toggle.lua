-- snacks.toggle spec: option toggles and their <leader>t… keymaps, registered on VeryLazy.

return {
	"folke/snacks.nvim",
	opts = {
		toggle = {
			map = vim.keymap.set,
			which_key = true, -- show enabled/disabled state via which-key
			notify = true, -- notify on toggle
			icon = {
				enabled = " ",
				disabled = " ",
			},
			-- colors for enabled/disabled states
			color = {
				enabled = "green",
				disabled = "yellow",
			},
			wk_desc = {
				enabled = "Disable ",
				disabled = "Enable ",
			},
		},
	},
	--- Registers all toggle keymaps once VeryLazy fires.
	---@return nil
	init = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			-- External: Snacks global exposes the toggle builders.
			callback = function()
				Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
				Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
				Snacks.toggle.diagnostics():map("<leader>ud")
				Snacks.toggle.line_number():map("<leader>ul")
				Snacks.toggle
					.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
					:map("<leader>uc")
				Snacks.toggle.treesitter():map("<leader>uT")
				Snacks.toggle
					.option("background", { off = "light", on = "dark", name = "Dark Background" })
					:map("<leader>ub")
				Snacks.toggle.inlay_hints():map("<leader>uh")
				Snacks.toggle.indent():map("<leader>ui")
				Snacks.toggle.words():map("<leader>uW")
				Snacks.toggle.dim():map("<leader>uD")
				Snacks.toggle.zoom():map("<leader>uZ")
				Snacks.toggle.zen():map("<leader>uz")
			end,
		})
	end,
}

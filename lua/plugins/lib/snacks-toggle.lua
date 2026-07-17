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
				Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>ts")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>tw")
				Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>tL")
				Snacks.toggle.diagnostics():map("<leader>td")
				Snacks.toggle.line_number():map("<leader>tl")
				Snacks.toggle
					.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
					:map("<leader>tc")
				Snacks.toggle.treesitter():map("<leader>tT")
				Snacks.toggle
					.option("background", { off = "light", on = "dark", name = "Dark Background" })
					:map("<leader>tb")
				Snacks.toggle.inlay_hints():map("<leader>th")
				Snacks.toggle.indent():map("<leader>ti")
				Snacks.toggle.words():map("<leader>tW")
				Snacks.toggle.dim():map("<leader>tD")
				Snacks.toggle.zoom():map("<leader>tZ")
				Snacks.toggle.zen():map("<leader>tz")
			end,
		})
	end,
}

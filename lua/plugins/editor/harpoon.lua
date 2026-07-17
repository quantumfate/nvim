--- harpoon: pin a short list of files and jump between them by slot or via a Snacks picker.
return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	event = "User FileOpened",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{
			"<leader>ha",
			function()
				require("harpoon"):list():add()
			end,
			desc = "Harpoon add",
		},
		{
			"<leader>hr",
			function()
				require("harpoon"):list():remove()
			end,
			desc = "Harpoon remove",
		},
		{
			"<leader>hl",
			-- Browse the harpoon list in a Snacks picker; confirm opens the file. `Snacks` is global.
			function()
				local items = {}
				for i, item in ipairs(require("harpoon"):list().items) do
					items[#items + 1] = { text = item.value, file = item.value, idx = i }
				end
				Snacks.picker.pick({
					title = "Harpoon",
					items = items,
					confirm = function(picker, item)
						picker:close()
						vim.cmd("edit " .. item.file)
					end,
				})
			end,
			desc = "Harpoon picker",
		},
		{
			"<c-h>",
			function()
				require("harpoon"):list():select(1)
			end,
			desc = "Harpoon 1",
		},
		{
			"<c-t>",
			function()
				require("harpoon"):list():select(2)
			end,
			desc = "Harpoon 2",
		},
		{
			"<c-n>",
			function()
				require("harpoon"):list():select(3)
			end,
			desc = "Harpoon 3",
		},
		{
			"<c-s>",
			function()
				require("harpoon"):list():select(4)
			end,
			desc = "Harpoon 4",
		},
	},
	-- Size the harpoon menu to the current window and enable auto-save on toggle.
	opts = function()
		require("harpoon"):setup({
			menu = {
				width = vim.api.nvim_win_get_width(0) - 4,
			},
			settings = {
				save_on_toggle = true,
			},
		})
	end,
}

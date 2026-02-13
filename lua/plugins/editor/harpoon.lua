return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	event = "User FileOpened",
	dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
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
			"<a-H>",
			function()
				require("harpoon"):list():select(1)
			end,
			desc = "Harpoon 1",
		},
		{
			"<a-T>",
			function()
				require("harpoon"):list():select(2)
			end,
			desc = "Harpoon 2",
		},
		{
			"<a-N>",
			function()
				require("harpoon"):list():select(3)
			end,
			desc = "Harpoon 3",
		},
		{
			"<a-S>",
			function()
				require("harpoon"):list():select(4)
			end,
			desc = "Harpoon 4",
		},
	},
	opts = {},
}

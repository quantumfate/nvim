return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	event = "VimEnter",
	build = ":CatppuccinCompile",
	opts = {
		integrations = {
			cmp = true,
			gitsigns = true,
			navic = true,
			nvimtree = true,
			notify = false,
			mini = {
				enabled = true,
				indentscope_color = "",
			},
		}
	}
}

return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {
		modes = {
			search = {
				enabled = false, -- Always enable flash during / and ? search
			},
			char = {
				enabled = true, -- Also for f, F, t, T motions
			},
		},
	},
    -- stylua: ignore
    keys = {
        { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
        { "S",     mode = { "n", "o", "x" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
        { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
        { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        {
            "<c-space>",
            mode = { "n", "o", "x" },
            function()
                require("flash").treesitter({
                    actions = {
                        ["<c-space>"] = "next",
                        ["<BS>"] = "prev"
                    }
                })
            end,
            desc = "Treesitter Incremental Selection"
        },
    },
}

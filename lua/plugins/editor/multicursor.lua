--- multicursor.nvim: multiple cursors spawned by motions, not by arrows.
---
--- The dialect lives in `lua/features/multicursor.lua`: `gz` arms a capture, the
--- next motion (or search) places a cursor, and a plugin keymap layer shadows the
--- movement keys only while a session is live — so nothing is remapped until
--- cursors exist, and which-key shows the runtime-enabled set by construction.
--- Keymap reference: `lua/core/README.md` ("Multiple cursors from motions").
return {
	"jake-stewart/multicursor.nvim",
	branch = "1.0",
	keys = {
		{
			"gz",
			mode = { "n", "x" },
			function()
				require("features.multicursor").arm()
			end,
			desc = "Cursor from next motion",
		},
	},
	config = function()
		require("features.multicursor").setup()
	end,
}

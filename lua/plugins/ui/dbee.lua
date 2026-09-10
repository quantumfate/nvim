return {
	"kndndrj/nvim-dbee",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	-- No trigger meant dbee, nui and logger all loaded at startup for a database UI
	-- that is opened deliberately or not at all.
	cmd = { "Dbee", "DbeeOpen", "DbeeClose", "DbeeToggle" },
	keys = {
		{
			"<leader>id",
			function()
				require("dbee").toggle()
			end,
			desc = "Database (dbee)",
		},
	},
	build = function()
		-- Install tries to automatically detect the install method.
		-- if it fails, try calling it with one of these parameters:
		--    "curl", "wget", "bitsadmin", "go"
		require("dbee").install()
	end,
	config = function()
		require("dbee").setup(--[[optional config]])
	end,
}

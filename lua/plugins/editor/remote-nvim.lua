--- remote-nvim.nvim: run and manage Neovim on remote hosts over SSH.
return {
	"amitds1997/remote-nvim.nvim",
	version = "*", -- pin to GitHub releases
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim", -- plugin UI
		"nvim-telescope/telescope.nvim", -- remote-method picker
	},
	cmd = { "RemoteStart", "RemoteStop", "RemoteInfo", "RemoteCleanup", "RemoteConfigDel", "RemoteLog" },
	config = true,
}

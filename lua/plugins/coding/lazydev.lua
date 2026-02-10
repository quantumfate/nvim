return {
	"folke/lazydev.nvim",
	ft = "lua",
	cmd = "LazyDev",
	opts = {
		library = {
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			{ path = "LazyVim", words = { "LazyVim" } },
			{ path = "snacks.nvim", words = { "Snacks" } },
		},
		integrations = {
			-- Fixes lspconfig's workspace management for LuaLS
			-- Only create a new workspace if the buffer is not part
			-- of an existing workspace or one of its libraries
			lspconfig = true,
			-- add the cmp source for completion of:
			-- `require "modname"`
			-- `---@module "modname"`
			cmp = false,
			-- same, but for Coq
			coq = false,
		},
		---@type boolean|(fun(root:string):boolean?)
		-- disable when a .luarc.json file is found
		enabled = function(root_dir)
			return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
		end,
	},
}

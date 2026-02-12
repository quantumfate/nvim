--- Enhanced Lua development environment with LSP workspace management
--- Provides intelligent completion and type checking for Neovim Lua development
---@class plugins.coding.lazydev
---@field setup fun(): nil

---@class LazydevConfig
---@field library table[] Library path configurations for type definitions
---@field integrations table Integration settings for external tools
---@field enabled boolean|fun(root_dir: string): boolean Whether to enable lazydev

return {
	"folke/lazydev.nvim",
	ft = "lua",
	cmd = "LazyDev",
	opts = {
		library = {
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			{ path = "LazyVim", words = { "LazyVim" } },
			{ path = "snacks.nvim", words = { "Snacks" } },
			{ path = vim.fn.stdpath("data") .. "/lazy", mods = {} },
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

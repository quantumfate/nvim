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
			-- Fix LuaLS workspace management: reuse the buffer's existing workspace/library.
			lspconfig = true,
			-- cmp/coq completion sources for `require`/`---@module` (blink is used instead).
			cmp = false,
			coq = false,
		},
		---@type boolean|(fun(root:string):boolean?)
		--- Off for standalone Lua projects that ship a .luarc.json, which should not see
		--- `vim.*`; on for Neovim configs and plugins even when they have one. This config
		--- is one: its luarc never expanded `$VIMRUNTIME`, so TSNode and friends were
		--- undefined in every file.
		enabled = function(root_dir)
			local nvim_shaped = vim.uv.fs_stat(root_dir .. "/lua") ~= nil
			return nvim_shaped or not vim.uv.fs_stat(root_dir .. "/.luarc.json")
		end,
	},
}

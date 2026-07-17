--- Entry point: bootstraps lazy.nvim, loads core config, then plugins and root detection.

--- Clone lazy.nvim into the data dir on first launch, aborting on clone failure.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Leaders must be set before lazy loads any mappings.
vim.g.mapleader = " " ---@type string external: read by every plugin mapping
vim.g.maplocalleader = "\\" ---@type string external: read by every plugin mapping

require("config")
require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
	checker = { enabled = true }, -- automatic plugin update checks
})

-- Root detection: register autocmds, then publish the spec globals it reads.
require("util.root").setup()
vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" } ---@type util.RootSpec[] external: read by util.root
vim.g.root_lsp_ignore = { "copilot" } ---@type string[] external: read by util.root.detectors.lsp

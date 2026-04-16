return {
	dir = os.getenv("PROJECT_DIR") .. "/github/quantumfate/lance.nvim",
	dev = true,
	keys = {
		{
			"<leader>Tl",
			function()
				local spec = vim.fn.expand("%:p")
				if not spec:match("_spec%.lua$") then
					vim.notify("Not a *_spec.lua file", vim.log.levels.WARN)
					return
				end
				local root = os.getenv("PROJECT_DIR") .. "/github/quantumfate/lance.nvim"
				local cmd = string.format(
					"nvim --headless "
						.. "-c \"lua vim.opt.rtp:prepend('%s')\" "
						.. "-c \"lua require('osv').launch({port=8086,blocking=true})\" "
						.. "-c \"luafile %s/tests/minimal_init.lua\" "
						.. "-c \"lua require('busted.runner')({standalone=false})\" "
						.. "-- --helper=%s/tests/minimal_init.lua %s",
					root,
					root,
					root,
					spec
				)
				vim.cmd("tabnew | terminal " .. cmd)
				vim.notify("osv listening on :8086 — attach via <leader>dSc", vim.log.levels.INFO)
			end,
			desc = "Debug lance spec via osv",
		},
	},
}

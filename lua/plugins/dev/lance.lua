-- Dev spec for the local lance.nvim plugin: adds a keymap to debug its busted specs via osv.

--- Launches a headless nvim that runs the current *_spec.lua under osv for remote debugging.
---@return nil
local function debug_current_spec()
	local spec = vim.fn.expand("%:p")
	if not spec:match("_spec%.lua$") then
		vim.notify("Not a *_spec.lua file", vim.log.levels.WARN)
		return
	end

	-- External: PROJECT_DIR env var locates the plugin checkout.
	local project_dir = os.getenv("PROJECT_DIR")
	if not project_dir then
		vim.notify("PROJECT_DIR environment variable is not set", vim.log.levels.WARN)
		return
	end
	local root = project_dir .. "/github/quantumfate/lance.nvim"
	local cmd = string.format(
		"nvim --headless "
			.. "-c \"lua vim.opt.rtp:prepend('%s')\" "
			.. "-c \"lua require('osv').launch({port=8086,blocking=true})\" "
			.. '-c "luafile %s/tests/minimal_init.lua" '
			.. "-c \"lua require('busted.runner')({standalone=false})\" "
			.. "-- --helper=%s/tests/minimal_init.lua %s",
		root,
		root,
		root,
		spec
	)
	vim.cmd("tabnew | terminal " .. cmd)
	vim.notify("osv listening on :8086 — attach via <leader>dSc", vim.log.levels.INFO)
end

local project_dir = os.getenv("PROJECT_DIR")
local lance_dir = project_dir and (project_dir .. "/github/quantumfate/lance.nvim") or nil
local exists = lance_dir ~= nil and vim.uv.fs_stat(lance_dir) ~= nil

-- An absent checkout yields NO spec at all: Lazy does not accept `dev = true`
-- without a dir, and CI (no lance checkout) must not be told to install it.
if not lance_dir or not exists then
	return {}
end

return {
	-- External: PROJECT_DIR env var locates the local dev checkout.
	dir = lance_dir,
	dev = true,
	keys = {
		{ "<leader>tD", debug_current_spec, desc = "Debug lance spec via osv" },
	},
}

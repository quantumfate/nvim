-- snacks.picker spec: input keymaps, a cwd/project-root toggle action, and the picker keybindings.

-- Non-code files hidden from the code-files picker (`<leader>fcf`). They are fd
-- `-E` patterns: no slash means matched against the basename at any depth, so
-- `docs` hides any file or directory named `docs` under the root. Hidden CI
-- dirs (.github, .circleci, …) need no entry: fd skips them by default.
local project_code_exclude = {
	--ft
	"*.txt",
	-- docs
	"Readme*",
	"AGENTS*",
	"CLAUDE*",
	"README*",
	"LICENSE*",
	"CHANGELOG*",
	"CONTRIBUTING*",
	"CODE_OF_CONDUCT*",
	"docs",
	"doc",
	-- generated dependency locks
	"package-lock.json",
	"yarn.lock",
	"pnpm-lock.yaml",
	"Cargo.lock",
	"go.sum",
	"poetry.lock",
	"Pipfile.lock",
	"Gemfile.lock",
	-- build files
	"justfile*",
	"makefile*",
}

-- Dot tool/vendor directories excluded from grep results. rg skips hidden
-- files and dirs by default, so these globs matter for the scoped greps that
-- walk an explicit directory (`fl/`, `fc/`) and stay effective if hidden search
-- is ever toggled on. `.git` is already excluded by snacks' base rg args.
local dot_dir_exclude = {
	".claude",
	".venv",
	".vscode",
	".idea",
	".terraform",
	".cache",
	".mypy_cache",
	".pytest_cache",
	".ruff_cache",
	".tox",
	".nox",
	".next",
	".nuxt",
	".gradle",
	".dart_tool",
	".elixir_ls",
}

--- Directory of the current buffer; falls back to the process cwd when the
--- buffer has no file name yet (mirrors features/sys/patch.lua).
---@return string
local function current_dir()
	local file = vim.api.nvim_buf_get_name(0)
	return vim.fs.normalize(file ~= "" and vim.fs.dirname(file) or vim.uv.cwd())
end

--- Project root of the current buffer.
---@return string
local function root()
	return require("lib.root")({ normalize = true })
end

--- Existing test directories under the project root: tests, test, spec, __tests__.
--- Warns and returns nil when the project has none, so callers skip opening a
--- picker over an empty scope instead of falling back to the whole cwd.
---@return string[]|nil
local function test_dirs()
	local dirs = {}
	for _, name in ipairs({ "tests", "test", "spec", "__tests__" }) do
		local dir = root() .. "/" .. name
		if vim.fn.isdirectory(dir) == 1 then
			dirs[#dirs + 1] = dir
		end
	end
	if #dirs == 0 then
		-- `Snacks` is a global from snacks.nvim.
		Snacks.notify.warn("No tests directory found under the project root", { title = "Tests" })
		return nil
	end
	return dirs
end

return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			win = {
				input = {
					show_first = false,
					keys = {
						["<a-c>"] = { "toggle_cwd", mode = { "n", "i" } },
						-- ["<a-v>"] = { "edit_vsplit", mode = { "n", "i" } },
						["<a-s>"] = { "edit_vsplit", mode = { "n", "i" } },
						-- Swap Tab/S-Tab with C-j/C-k
						["<Tab>"] = { "list_down", mode = { "n", "i" } },
						["<S-Tab>"] = { "list_up", mode = { "n", "i" } },
						["<C-j>"] = { "select_and_next", mode = { "n", "i" } },
						["<C-k>"] = { "select_and_prev", mode = { "n", "i" } },
					},
				},
			},
			actions = {
				--- Toggles the picker's cwd between the project root and the process cwd.
				---@param p snacks.Picker
				toggle_cwd = function(p)
					local root = require("lib.root").get({ buf = p.input.filter.current_buf, normalize = true })
					local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
					p:set_cwd(p:cwd() == root and cwd or root)
					p:find()
				end,
			},
		},
	},
	keys = {
		-- whole project (scoped to the root)
		{
			"<leader>ff",
			function()
				Snacks.picker.files({ cwd = root() })
			end,
			desc = "Find All Files (project root)",
		},
		{
			"<leader><cr>",
			function()
				Snacks.picker.smart({ filter = { cwd = require("lib.root")() } })
			end,
			desc = "Find files based on current project root",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Find Files",
		},
		-- code (no docs, CI, or lockfiles)
		{
			"<leader>fcf",
			function()
				Snacks.picker.files({
					cwd = root(),
					exclude = project_code_exclude,
				})
			end,
			desc = "Find Code Files (project root)",
		},
		{
			"<leader>fc/",
			function()
				Snacks.picker.grep({
					cwd = root(),
					exclude = vim.tbl_flatten({ project_code_exclude, dot_dir_exclude }),
				})
			end,
			desc = "Grep Code Files (project root)",
		},
		-- tests (tests/test/spec dirs under the root)
		{
			"<leader>ftf",
			function()
				local dirs = test_dirs()
				if dirs then
					Snacks.picker.files({ dirs = dirs })
				end
			end,
			desc = "Find Test Files",
		},
		{
			"<leader>ft/",
			function()
				local dirs = test_dirs()
				if dirs then
					Snacks.picker.grep({ dirs = dirs, exclude = dot_dir_exclude })
				end
			end,
			desc = "Grep Tests",
		},
		-- local (the current file's directory)
		{
			"<leader>flf",
			function()
				Snacks.picker.files({ cwd = current_dir() })
			end,
			desc = "Find Files in Current File's Directory",
		},
		{
			"<leader>fl/",
			function()
				Snacks.picker.grep({ dirs = { current_dir() }, exclude = dot_dir_exclude })
			end,
			desc = "Grep in Current File's Directory",
		},
		{
			"<leader>/",
			function()
				Snacks.picker.grep({ exclude = dot_dir_exclude })
			end,
			desc = "Grep",
		},
		{
			"<leader>:",
			function()
				Snacks.picker.command_history()
			end,
			desc = "Command History",
		},
		{
			"<leader>dbf",
			-- Collects all DAP breakpoints into a picker that jumps to the chosen line.
			function()
				local breakpoints = require("dap.breakpoints").get()
				local items = {}
				for bufnr, buf_bps in pairs(breakpoints) do
					for _, bp in ipairs(buf_bps) do
						local filename = vim.api.nvim_buf_get_name(bufnr)
						items[#items + 1] = {
							text = filename .. ":" .. bp.line,
							file = filename,
							pos = { bp.line, 0 },
						}
					end
				end
				Snacks.picker.pick({
					title = "Breakpoints",
					items = items,
					confirm = function(picker, item)
						picker:close()
						vim.cmd("edit " .. item.file)
						vim.api.nvim_win_set_cursor(0, item.pos)
					end,
				})
			end,
			desc = "List breakpoints",
		},
		-- find
		{
			"<leader>fi",
			function()
				Snacks.picker.icons()
			end,
			desc = "Icons",
		},
		{
			"<leader>fk",
			function()
				Snacks.picker.keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<leader>fM",
			function()
				Snacks.picker.man()
			end,
			desc = "Man Pages",
		},
		{
			"<leader>fu",
			function()
				Snacks.picker.undo()
			end,
			desc = "Undo History",
		},
		{
			"<leader>fl",
			function()
				Snacks.picker.lazy()
			end,
			desc = "Search for Plugin Spec",
		},
		-- git
		{
			"<leader>fgb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git Branches",
		},
		{
			"<leader>fgl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "Git Log",
		},
		{
			"<leader>fgL",
			function()
				Snacks.picker.git_log_line()
			end,
			desc = "Git Log Line",
		},
		{
			"<leader>fgs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "Git Status",
		},
		{
			"<leader>fgS",
			function()
				Snacks.picker.git_stash()
			end,
			desc = "Git Stash",
		},
		{
			"<leader>fgd",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "Git Diff (Hunks)",
		},
		{
			"<leader>fgf",
			function()
				Snacks.picker.git_log_file()
			end,
			desc = "Git Log File",
		},
		-- gh
		{
			"<leader>fgi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "GitHub Issues (open)",
		},
		{
			"<leader>fgI",
			function()
				Snacks.picker.gh_issue({ state = "all" })
			end,
			desc = "GitHub Issues (all)",
		},
		{
			"<leader>fgp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "GitHub Pull Requests (open)",
		},
		{
			"<leader>fgP",
			function()
				Snacks.picker.gh_pr({ state = "all" })
			end,
			desc = "GitHub Pull Requests (all)",
		},
		-- --lsp
		-- {
		-- 	"<leader>flw",
		-- 	function()
		-- 		Snacks.picker.lsp_workspace_symbols()
		-- 	end,
		-- 	desc = "LSP workspace symbols",
		-- },
		-- {
		-- 	"<leader>fls",
		-- 	function()
		-- 		Snacks.picker.treesitter()
		-- 	end,
		-- 	desc = "Treesitter symbols",
		-- },
		-- {
		-- 	"<leader>fld",
		-- 	function()
		-- 		Snacks.picker.lsp_type_definitions()
		-- 	end,
		-- 	desc = "LSP type definitions",
		-- },
		-- {
		-- 	"<leader>fll",
		-- 	function()
		-- 		Snacks.picker.lsp_symbols()
		-- 	end,
		-- 	desc = "LSP document symbols",
		-- },
	},
}

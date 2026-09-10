--- refactoring.nvim spec: treesitter-driven extract/inline refactors and debug
--- print scaffolding, bound under the shared <leader>r refactor group.

--- Filetypes the plugin ships queries for (its own `queries/` directory).
--- Rust and Zig have none, so they get no refactor group.
---@type string[]
local supported_ft = {
	"c",
	"cpp",
	"cs",
	"go",
	"java",
	"javascript",
	"javascriptreact",
	"typescript",
	"typescriptreact",
	"lua",
	"php",
	"ps1",
	"python",
	"ruby",
	"vim",
}

--- Inline Function additionally needs `refactor_function` and
--- `refactor_function_call` queries, which only Lua ships today.
---@type string[]
local inline_func_ft = { "lua" }

--- Every refactor is an operator: the entrypoint arms `operatorfunc` and hands
--- back the keys to trigger it. From visual mode the selection has to be
--- restored with `gv` first, mirroring the plugin's own select_refactor.
---@param mod string Module to pull the entrypoint from
---@param name string Entrypoint function name
---@return fun()
local function operator(mod, name)
	return function()
		local mode = vim.api.nvim_get_mode().mode
		local keys = require(mod)[name]()
		if (mode == "v" or mode == "V" or mode == "\22") and keys == "g@" then
			keys = "gv" .. keys
		end
		vim.api.nvim_input(keys)
	end
end

--- `extract_func_to_file` only calls `bufadd` + `bufload` (its source carries an
--- open TODO about this): the new file exists as an unwritten buffer, nothing
--- opens it and nothing reports its path. neo-tree lists the filesystem, so the
--- file stays invisible until it is written.
---
--- Arm a one-shot BufNewFile around the refactor, wait for the async extract to
--- fill the buffer, then write it and report where it went. neo-tree picks it up
--- from there via its libuv watcher.
---@param buf integer
---@param tries integer Remaining polls before giving up
local function write_extracted(buf, tries)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local empty = #lines == 0 or (#lines == 1 and lines[1] == "")
	if empty then
		if tries > 0 then
			vim.defer_fn(function()
				write_extracted(buf, tries - 1)
			end, 50)
		end
		return
	end

	vim.api.nvim_buf_call(buf, function()
		vim.cmd("write")
	end)
	Snacks.notify.info(("Extracted to %s"):format(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")))
end

--- Wraps extract_func_to_file so the created file lands on disk.
---@return fun()
local function extract_to_file()
	return function()
		local group = vim.api.nvim_create_augroup("refactoring_extract_to_file", { clear = true })

		vim.api.nvim_create_autocmd("BufNewFile", {
			group = group,
			once = true,
			callback = function(event)
				write_extracted(event.buf, 40)
			end,
		})

		-- Disarm if the refactor was cancelled, so an unrelated `:e newfile`
		-- later on is not mistaken for the extracted buffer.
		vim.defer_fn(function()
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end, 30000)

		operator("refactoring", "extract_func_to_file")()
	end
end

--- Range refactors are operators: in normal mode they wait for a motion, in
--- visual mode they consume the selection. Each gets its own description so
--- which-key states what the key will actually do in the mode you are in.
---@type { lhs: string, mod: string?, fn: string?, action: fun()?, n: string, x: string }[]
local ranged = {
	{
		lhs = "<leader>re",
		mod = "refactoring",
		fn = "extract_func",
		n = "Statements under motion -> new function",
		x = "Selected statements -> new function",
	},
	{
		lhs = "<leader>rE",
		action = extract_to_file(),
		n = "Statements under motion -> function in a new file (written)",
		x = "Selected statements -> function in a new file (written)",
	},
	{
		lhs = "<leader>rv",
		mod = "refactoring",
		fn = "extract_var",
		n = "Expression under motion -> named local, all uses replaced",
		x = "Selected expression -> named local, all uses replaced",
	},
	{
		lhs = "<leader>rpv",
		mod = "refactoring.debug",
		fn = "print_var",
		n = "Print every variable under motion",
		x = "Print every variable in selection",
	},
	{
		lhs = "<leader>rpe",
		mod = "refactoring.debug",
		fn = "print_exp",
		n = "Print expression under motion",
		x = "Print selected expression",
	},
}

--- Cursor-anchored refactors return `g@l`, supplying their own range. They take
--- no motion and no selection, so they are normal mode only.
---@type { lhs: string, mod: string, fn: string, desc: string }[]
local cursor = {
	{
		lhs = "<leader>ri",
		mod = "refactoring",
		fn = "inline_var",
		desc = "Variable under cursor -> its value at every reference",
	},
	{
		lhs = "<leader>rpl",
		mod = "refactoring.debug",
		fn = "print_loc",
		desc = "Print the code path reaching this line",
	},
}

--- Debug prints accumulate across a file, so cleanup is almost always wanted
--- buffer-wide. Select the whole buffer, then run the operator over it.
local function cleanup_buffer()
	vim.api.nvim_input("ggVG" .. require("refactoring.debug").cleanup())
end

--- Builds the two which-key entries (normal, visual) for each range refactor.
---@param buf integer
---@return table
local function ranged_keymaps(buf)
	local spec = { buffer = buf }
	for _, item in ipairs(ranged) do
		local action = item.action or operator(item.mod, item.fn)
		table.insert(spec, { item.lhs, action, desc = item.n, mode = "n" })
		table.insert(spec, { item.lhs, action, desc = item.x, mode = "x" })
	end
	return spec
end

--- Builds the normal-mode entries for the cursor-anchored refactors.
---@param buf integer
---@return table
local function cursor_keymaps(buf)
	local spec = { buffer = buf }
	for _, item in ipairs(cursor) do
		table.insert(spec, { item.lhs, operator(item.mod, item.fn), desc = item.desc, mode = "n" })
	end
	table.insert(spec, {
		"<leader>rpc",
		cleanup_buffer,
		desc = "Remove every debug print in this buffer",
		mode = "n",
	})
	return spec
end

return {
	"ThePrimeagen/refactoring.nvim",
	dependencies = {
		-- Required since the rewrite; plenary is no longer used at all.
		"lewis6991/async.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	ft = supported_ft,
	--- Runs before the plugin loads, so the first require("async") from either
	--- refactoring.nvim or nvim-ufo already resolves to the right copy.
	init = function()
		require("lib.async_shim").setup()
	end,
	---@type refactor.UserConfig
	opts = {
		show_success_message = true,
	},
	--- Register refactor keymaps per buffer once its filetype is known.
	config = function(_, opts)
		require("refactoring").setup(opts)

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("refactoring_keymaps", { clear = true }),
			pattern = supported_ft,
			callback = function(event)
				local buf = event.buf

				-- Refactors need a treesitter parse; skip buffers without one.
				if not pcall(vim.treesitter.get_parser, buf) then
					return
				end

				local wk = require("which-key")

				wk.add({
					buffer = buf,
					{ "<leader>r", group = "refactor" },
					-- `<leader>rr` is deliberately absent: it belongs to the engine's menu
					-- in lua/features/refactor/, which lists these refactorings too. This
					-- plugin's own picker is still one entry inside it, and `<leader>rR`
					-- below reaches it directly.
					{
						"<leader>rR",
						function()
							require("refactoring").select_refactor()
						end,
						desc = "Menu, apply immediately",
						mode = { "n", "x" },
					},
					{ "<leader>rp", group = "print" },
				})
				wk.add(ranged_keymaps(buf))
				wk.add(cursor_keymaps(buf))

				if vim.tbl_contains(inline_func_ft, vim.bo[buf].filetype) then
					wk.add({
						buffer = buf,
						{
							"<leader>rI",
							operator("refactoring", "inline_func"),
							desc = "Function under cursor -> its body at every call",
							mode = "n",
						},
					})
				end
			end,
		})
	end,
}

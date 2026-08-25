--- zig.vim spec: official Zig filetype plugin plus project-aware build/run/test keymaps.
return {
	"ziglang/zig.vim",
	ft = { "zig" },
	init = function()
		-- conform.nvim owns formatting via `zig fmt`; keep zig.vim's autosave hook off.
		vim.g.zig_fmt_autosave = 0
	end,
	config = function()
		--- Nearest directory containing build.zig, or nil for standalone files.
		---@return string|nil
		local function project_root()
			local start = vim.api.nvim_buf_get_name(0)
			start = start ~= "" and vim.fs.dirname(start) or vim.uv.cwd()
			local found = vim.fs.find("build.zig", { upward = true, path = start })[1]
			return found and vim.fs.dirname(found) or nil
		end

		--- Directory of the current buffer, falling back to cwd for unsaved buffers.
		---@return string
		local function buffer_dir()
			local path = vim.api.nvim_buf_get_name(0)
			return path ~= "" and vim.fs.dirname(path) or vim.uv.cwd()
		end

		--- Run `zig ...` inside a stacked Snacks terminal rooted at the project (if any).
		---@param args string[] Arguments passed after the `zig` executable
		local function zig_term(args)
			Snacks.terminal(vim.list_extend({ "zig" }, args), {
				cwd = project_root() or buffer_dir(),
			})
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("zig_setup", { clear = true }),
			pattern = "zig",
			callback = function(ev)
				local buf = ev.buf
				local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))

				vim.keymap.set("n", "<leader>zb", function()
					zig_term({ "build" })
				end, { buffer = buf, desc = "Zig Build" })

				-- Project workspaces route through build.zig; lone files compile directly.
				vim.keymap.set("n", "<leader>zr", function()
					if project_root() then
						zig_term({ "build", "run" })
					else
						zig_term({ "run", path })
					end
				end, { buffer = buf, desc = "Zig Run" })

				vim.keymap.set("n", "<leader>zt", function()
					if project_root() then
						zig_term({ "build", "test" })
					else
						zig_term({ "test", path })
					end
				end, { buffer = buf, desc = "Zig Test" })

				-- Parse/AST lint without compiling; catches syntax errors fast.
				vim.keymap.set("n", "<leader>za", function()
					zig_term({ "ast-check", path })
				end, { buffer = buf, desc = "Zig Ast-check" })
			end,
		})

		-- zls is provisioned by Mason automatically; the compiler must be installed manually.
		if vim.fn.executable("zig") == 0 then
			vim.notify(
				"**zig** not found in PATH, please install it.\nhttps://ziglang.org/download/",
				vim.log.levels.ERROR,
				{ title = "zig.vim" }
			)
		end
	end,
}

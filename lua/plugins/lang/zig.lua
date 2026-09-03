--- zig.vim spec: official Zig filetype plugin plus project-aware build/run/test keymaps.
return {
	"ziglang/zig.vim",
	ft = { "zig" },
	init = function()
		-- conform.nvim owns formatting via `zig fmt`; keep zig.vim's autosave hook off.
		vim.g.zig_fmt_autosave = 0
	end,
	config = function()
		local root = require("util.root")

		--- Nearest directory containing build.zig, or nil for standalone files. The
		--- pattern detector stops at the first match rather than falling back to cwd,
		--- which is what makes "is this a workspace?" answerable below.
		---@param buf integer
		---@return string|nil
		local function project_root(buf)
			return root.detectors.pattern(buf, "build.zig")[1]
		end

		--- Run `zig ...` inside a stacked Snacks terminal rooted at the project, or at
		--- the buffer's own root (lsp / .git / cwd) for a file with no build.zig.
		---@param buf integer
		---@param args string[] Arguments passed after the `zig` executable
		local function zig_term(buf, args)
			Snacks.terminal(vim.list_extend({ "zig" }, args), {
				cwd = project_root(buf) or root.get({ buf = buf }),
			})
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("zig_setup", { clear = true }),
			pattern = "zig",
			callback = function(ev)
				local buf = ev.buf
				local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))

				vim.keymap.set("n", "<leader>zb", function()
					zig_term(buf, { "build" })
				end, { buffer = buf, desc = "Zig Build" })

				-- Project workspaces route through build.zig; lone files compile directly.
				vim.keymap.set("n", "<leader>zr", function()
					if project_root(buf) then
						zig_term(buf, { "build", "run" })
					else
						zig_term(buf, { "run", path })
					end
				end, { buffer = buf, desc = "Zig Run" })

				vim.keymap.set("n", "<leader>zt", function()
					if project_root(buf) then
						zig_term(buf, { "build", "test" })
					else
						zig_term(buf, { "test", path })
					end
				end, { buffer = buf, desc = "Zig Test" })

				-- Parse/AST lint without compiling; catches syntax errors fast.
				vim.keymap.set("n", "<leader>za", function()
					zig_term(buf, { "ast-check", path })
				end, { buffer = buf, desc = "Zig Ast-check" })
			end,
		})
	end,
}

--- nvim-treesitter stack: parsers plus highlight/indent/fold wiring, textobjects, autotag, comments.
---@class plugins.editor.treesitter
---@field setup fun(): nil

---@class TreesitterConfig
---@field ensure_installed string[] Languages to automatically install parsers for
---@field highlight table Syntax highlighting configuration
---@field indent table Automatic indentation settings
---@field folds table Code folding configuration

return {
	{
		"nvim-treesitter/nvim-treesitter",
		version = false,
		build = ":TSUpdate",
		branch = "main",
		event = { "VeryLazy" },
		cmd = { "TSUpdate", "TSInstall", "TSUninstall" },
		opts = {
			ensure_installed = {
				"bash",
				"c",
				"cpp",
				"css",
				"diff",
				"go",
				"html",
				"javascript",
				"jsdoc",
				"json",
				"latex",
				"lua",
				"luadoc",
				"luap",
				"markdown",
				"markdown_inline",
				"printf",
				"python",
				"query",
				"regex",
				"rust",
				"ron",
				"scss",
				"sql",
				"svelte",
				"toml",
				"tsx",
				"typescript",
				"typst",
				"vim",
				"vimdoc",
				"vue",
				"xml",
				"yaml",
				"qmljs",
			},
			highlight = { enable = true },
			indent = { enable = true },
			folds = { enable = true },
		},
		-- Install missing parsers, register custom query directives/textobjects, and enable per-buffer.
		config = function(_, opts)
			local ts = require("nvim-treesitter")
			ts.setup(opts)

			local installed = ts.get_installed and ts.get_installed() or {}
			local to_install = vim.tbl_filter(function(lang)
				return not vim.tbl_contains(installed, lang)
			end, opts.ensure_installed or {})

			if #to_install > 0 then
				ts.install(to_install)
			end

			-- Custom query directives and function textobjects from the local util module.
			local ts_util = require("util.plugins.treesitter")
			vim.treesitter.query.add_directive("downcase!", ts_util.case_directive(string.lower), { force = true })
			vim.treesitter.query.add_directive("upcase!", ts_util.case_directive(string.upper), { force = true })

			vim.keymap.set({ "x", "o" }, "af", function()
				ts_util.select_function("function.outer")
			end, { desc = "around function" })
			vim.keymap.set({ "x", "o" }, "if", function()
				ts_util.select_function("function.inner")
			end, { desc = "inside function" })

			-- Enable highlighting and treesitter folds for any buffer with an available parser.
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter_setup", { clear = true }),
				callback = function(ev)
					local buf = ev.buf
					local ft = ev.match

					local lang = vim.treesitter.language.get_lang(ft)
					local has_parser = pcall(vim.treesitter.language.inspect, lang or ft)
					if not has_parser then
						return
					end

					if opts.highlight and opts.highlight.enable ~= false then
						pcall(vim.treesitter.start, buf)
					end

					-- Switch manual folding over to the treesitter fold expression.
					if opts.folds and opts.folds.enable ~= false then
						if vim.wo[0].foldmethod == "manual" then
							vim.wo[0].foldmethod = "expr"
							vim.wo[0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
							vim.wo[0].foldlevel = 99
						end
					end
				end,
			})

			pcall(vim.treesitter.start)
		end,
	},

	-- Treesitter textobjects: jump between functions/classes/parameters.
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = "User FileOpened",
		config = function()
			local move = require("nvim-treesitter-textobjects.move")

			-- Bind a normal/visual/operator key to a textobject move method.
			---@param key string
			---@param query string Textobject capture, e.g. "@function.outer"
			---@param method string Move function name on the move module
			---@param desc string
			local function map(key, query, method, desc)
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move[method](query, "textobjects")
				end, { desc = desc, silent = true })
			end

			-- Next
			map("]f", "@function.outer", "goto_next_start", "Next Function Start")
			map("]F", "@function.outer", "goto_next_end", "Next Function End")
			map("]c", "@class.outer", "goto_next_start", "Next Class Start")
			map("]C", "@class.outer", "goto_next_end", "Next Class End")
			map("]a", "@parameter.inner", "goto_next_start", "Next Parameter Start")
			map("]A", "@parameter.inner", "goto_next_end", "Next Parameter End")

			-- Previous
			map("[f", "@function.outer", "goto_previous_start", "Prev Function Start")
			map("[F", "@function.outer", "goto_previous_end", "Prev Function End")
			map("[c", "@class.outer", "goto_previous_start", "Prev Class Start")
			map("[C", "@class.outer", "goto_previous_end", "Prev Class End")
			map("[a", "@parameter.inner", "goto_previous_start", "Prev Parameter Start")
			map("[A", "@parameter.inner", "goto_previous_end", "Prev Parameter End")
		end,
	},

	-- Auto close/rename HTML/JSX tags.
	{
		"windwp/nvim-ts-autotag",
		event = "BufReadPost",
		opts = {},
	},
	-- Treesitter-aware commentstring per language.
	{
		"folke/ts-comments.nvim",
		event = "User FileType",
		opts = {},
	},
}

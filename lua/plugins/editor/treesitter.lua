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
				"zig",
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

			-- Compound filetypes have no parser of their own; point them at their base grammar
			-- so highlight/indent/folds work in e.g. Ansible playbooks.
			for ft, lang in pairs({
				["yaml.ansible"] = "yaml",
				["yaml.docker-compose"] = "yaml",
				["yaml.gitlab"] = "yaml",
			}) do
				vim.treesitter.language.register(lang, ft)
			end

			-- Custom query directives from the local util module. Function textobjects
			-- (af/if, ac/ic, ...) come from mini.ai, which handles counts and next/last.
			local ts_util = require("util.plugins.treesitter")
			vim.treesitter.query.add_directive("downcase!", ts_util.case_directive(string.lower), { force = true })
			vim.treesitter.query.add_directive("upcase!", ts_util.case_directive(string.upper), { force = true })

			-- Node-wise incremental selection, the treesitter answer to visual mode.
			local ts_select = require("util.plugins.ts_select")
			vim.keymap.set({ "n", "x" }, "<c-space>", ts_select.expand, { desc = "Expand selection to node" })
			vim.keymap.set("x", "<bs>", ts_select.shrink, { desc = "Shrink selection to child node" })
			vim.api.nvim_create_autocmd("ModeChanged", {
				group = vim.api.nvim_create_augroup("ts_select_reset", { clear = true }),
				pattern = "[vV\x16]*:[^vV\x16]*",
				callback = function(ev)
					ts_select.reset(ev.buf)
				end,
			})

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

	-- Treesitter textobjects: structural motion (]f, [c, ...) and structural swaps.
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = "User FileOpened",
		config = function()
			local move = require("nvim-treesitter-textobjects.move")
			local swap = require("nvim-treesitter-textobjects.swap")
			local repeatable = require("nvim-treesitter-textobjects.repeatable_move")

			-- Forward / backward prefixes. `-` and `_` are the layout-native pair (see
			-- config/keymaps.lua); the bracket spellings stay as aliases.
			local forward, backward = { "-", "]" }, { "_", "[" }

			-- Bind a motion in both directions under both prefixes, wrapped so `;` / `,`
			-- replay it.
			---@param key string Suffix; the uppercase variant targets the node end.
			---@param query string Textobject capture, e.g. "@function.outer"
			---@param label string Used to build the descriptions
			local function motion(key, query, label)
				local specs = {
					{ forward, key, "goto_next_start", "Next " .. label .. " start" },
					{ forward, key:upper(), "goto_next_end", "Next " .. label .. " end" },
					{ backward, key, "goto_previous_start", "Prev " .. label .. " start" },
					{ backward, key:upper(), "goto_previous_end", "Prev " .. label .. " end" },
				}
				for _, spec in ipairs(specs) do
					local prefixes, suffix, method, desc = spec[1], spec[2], spec[3], spec[4]
					local fn = repeatable.make_repeatable_move(function()
						move[method](query, "textobjects")
					end)
					for _, prefix in ipairs(prefixes) do
						vim.keymap.set({ "n", "x", "o" }, prefix .. suffix, fn, { desc = desc, silent = true })
					end
				end
			end

			motion("f", "@function.outer", "function")
			motion("c", "@class.outer", "class")
			motion("a", "@parameter.inner", "parameter")
			motion("o", "@block.outer", "block")
			motion("i", "@conditional.outer", "conditional")
			motion("l", "@loop.outer", "loop")
			motion("v", "@assignment.outer", "assignment")
			motion("r", "@return.outer", "return")

			-- `;` / `,` replay the last treesitter motion (and fall back to f/t repeat).
			vim.keymap.set({ "n", "x", "o" }, ";", repeatable.repeat_last_move, { desc = "Repeat last move" })
			vim.keymap.set(
				{ "n", "x", "o" },
				",",
				repeatable.repeat_last_move_opposite,
				{ desc = "Repeat last move (reverse)" }
			)

			-- Structural swaps: exchange the node under the cursor with its sibling.
			---@param key string Suffix after `<leader>m`; uppercase swaps backwards
			---@param query string
			---@param label string
			local function swap_pair(key, query, label)
				vim.keymap.set("n", "<leader>m" .. key, function()
					swap.swap_next(query)
				end, { desc = "Swap " .. label .. " forward" })
				vim.keymap.set("n", "<leader>m" .. key:upper(), function()
					swap.swap_previous(query)
				end, { desc = "Swap " .. label .. " backward" })
			end

			swap_pair("a", "@parameter.inner", "parameter")
			swap_pair("f", "@function.outer", "function")
			swap_pair("c", "@class.outer", "class")
			swap_pair("v", "@assignment.inner", "assignment")
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

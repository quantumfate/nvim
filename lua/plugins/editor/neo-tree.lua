return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	cmd = "Neotree",
	keys = {
		{
			"<leader>e",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.fn.getcwd() })
			end,
			desc = "Explorer NeoTree (cwd)",
		},
		{
			"<leader>E",
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.fn.expand("%:p:h") })
			end,
			desc = "Explorer NeoTree (current file)",
		},
		{
			"<leader>ge",
			function()
				require("neo-tree.command").execute({ source = "git_status", toggle = true })
			end,
			desc = "Git Explorer",
		},
		{
			"<leader>be",
			function()
				require("neo-tree.command").execute({ source = "buffers", toggle = true })
			end,
			desc = "Buffer Explorer",
		},
	},
	deactivate = function()
		vim.cmd([[Neotree close]])
	end,
	init = function()
		-- FIX: use `autocmd` for lazy-loading neo-tree instead of directly requiring it,
		-- because `cwd` is not set up properly.
		vim.api.nvim_create_autocmd("BufEnter", {
			group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
			desc = "Start Neo-tree with directory",
			once = true,
			callback = function()
				if package.loaded["neo-tree"] then
					return
				else
					local stats = vim.uv.fs_stat(vim.fn.argv(0))
					if stats and stats.type == "directory" then
						require("neo-tree")
					end
				end
			end,
		})
	end,
	opts = {
		sources = { "filesystem", "buffers", "git_status" },
		open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline", "edgy" },
		filesystem = {
			bind_to_cwd = false,
			follow_current_file = { enabled = true },
			use_libuv_file_watcher = true,
		},
		window = {
			mappings = {
				["<space>"] = "none",
				["Y"] = {
					function(state)
						local node = state.tree:get_node()
						local path = node:get_id()
						vim.fn.setreg("+", path, "c")
					end,
					desc = "Copy Path to Clipboard",
				},
				["O"] = {
					function(state)
						require("lazy.util").open(state.tree:get_node().path, { system = true })
					end,
					desc = "Open with System Application",
				},
				["P"] = { "toggle_preview", config = { use_float = false } },
				-- Avante integration mappings
				["aa"] = {
					function(state)
						local node = state.tree:get_node()
						if node.type == "file" then
							-- Open file and ask Avante about it
							vim.cmd("edit " .. node.path)
							vim.cmd("AvanteAsk")
						end
					end,
					desc = "Avante: Ask about file",
				},
				["ae"] = {
					function(state)
						local node = state.tree:get_node()
						if node.type == "file" then
							-- Open file and edit with Avante
							vim.cmd("edit " .. node.path)
							vim.cmd("AvanteEdit")
						end
					end,
					desc = "Avante: Edit file",
				},
				["ar"] = {
					function(state)
						local node = state.tree:get_node()
						if node.type == "file" then
							-- Open file and review with Avante
							vim.cmd("edit " .. node.path)
							vim.cmd("AvanteAsk")
							vim.api.nvim_feedkeys(
								"Review this code for potential issues and suggest improvements:",
								"n",
								false
							)
						end
					end,
					desc = "Avante: Code review",
				},
				["ad"] = {
					function(state)
						local node = state.tree:get_node()
						if node.type == "file" then
							-- Open file and document with Avante
							vim.cmd("edit " .. node.path)
							vim.cmd("AvanteAsk")
							vim.api.nvim_feedkeys("Add comprehensive documentation to this code:", "n", false)
						end
					end,
					desc = "Avante: Add documentation",
				},
			},
		},
		default_component_configs = {
			indent = {
				with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
				expander_collapsed = "",
				expander_expanded = "",
				expander_highlight = "NeoTreeExpander",
			},
			git_status = {
				symbols = {
					unstaged = "󰄱",
					staged = "󰱒",
				},
			},
		},
	},
	config = function(_, opts)
		local function on_move(data)
			Snacks.util.lsp.on_rename(data.source, data.destination)
		end

		local events = require("neo-tree.events")
		opts.event_handlers = opts.event_handlers or {}
		vim.list_extend(opts.event_handlers, {
			{ event = events.FILE_MOVED, handler = on_move },
			{ event = events.FILE_RENAMED, handler = on_move },
		})
		require("neo-tree").setup(opts)
		vim.api.nvim_create_autocmd("TermClose", {
			pattern = "*lazygit",
			callback = function()
				if package.loaded["neo-tree.sources.git_status"] then
					require("neo-tree.sources.git_status").refresh()
				end
			end,
		})
	end,
}

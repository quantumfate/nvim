--- neo-tree.nvim: file/buffer/git-status sidebar explorer with LSP-aware move/rename handling.
return {
	{
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
				"<leader>ee",
				function()
					require("neo-tree.command").execute({ toggle = true, dir = vim.fn.getcwd() })
				end,
				desc = "Explorer NeoTree (cwd)",
			},
			{
				"<leader>eE",
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
				"<leader>eb",
				function()
					require("neo-tree.command").execute({ source = "buffers", toggle = true })
				end,
				desc = "Buffer Explorer",
			},
		},
		-- Close the explorer when lazy.nvim deactivates the plugin.
		deactivate = function()
			vim.cmd([[Neotree close]])
		end,
		-- Lazy-load neo-tree via autocmd (not a direct require) so `cwd` is set before load.
		init = function()
			vim.api.nvim_create_autocmd("BufEnter", {
				group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
				desc = "Start Neo-tree with directory",
				once = true,
				callback = function()
					if package.loaded["neo-tree"] then
						return
					end
					local stats = vim.uv.fs_stat(vim.fn.argv(0))
					if stats and stats.type == "directory" then
						require("neo-tree")
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
						-- Yank the selected node's path to the system clipboard.
						function(state)
							local path = state.tree:get_node():get_id()
							vim.fn.setreg("+", path, "c")
						end,
						desc = "Copy Path to Clipboard",
					},
					["O"] = {
						-- Open the selected node with the OS default application.
						function(state)
							require("lazy.util").open(state.tree:get_node().path, { system = true })
						end,
						desc = "Open with System Application",
					},
					["P"] = { "toggle_preview", config = { use_float = true } },
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
		-- Wire file move/rename events into LSP updates and refresh git status after lazygit.
		config = function(_, opts)
			-- Propagate a tree move/rename to LSP clients. `Snacks` is a global from snacks.nvim.
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

			-- Refresh the git_status source when a lazygit terminal closes.
			vim.api.nvim_create_autocmd("TermClose", {
				pattern = "*lazygit",
				callback = function()
					if package.loaded["neo-tree.sources.git_status"] then
						require("neo-tree.sources.git_status").refresh()
					end
				end,
			})
		end,
	},
}

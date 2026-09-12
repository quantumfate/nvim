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
					require("features.ui.sidebar").toggle("filesystem")
				end,
				desc = "Explorer NeoTree (files)",
			},
			{
				"<leader>eE",
				function()
					require("neo-tree.command").execute({ toggle = true, dir = vim.fn.expand("%:p:h") })
				end,
				desc = "Explorer NeoTree (current file)",
			},
			{
				"<leader>eg",
				function()
					require("features.ui.sidebar").toggle("git_status")
				end,
				desc = "Explorer NeoTree (git status)",
			},
			{
				"<leader>eb",
				function()
					require("features.ui.sidebar").toggle("buffers")
				end,
				desc = "Explorer NeoTree (buffers)",
			},
			-- `<leader>g` is the git group; the git tree answers to both spellings.
			{
				"<leader>ge",
				function()
					require("features.ui.sidebar").toggle("git_status")
				end,
				desc = "Git Explorer",
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
					local stats = vim.uv.fs_stat(vim.fn.argv(0) --[[@as string]])
					if stats and stats.type == "directory" then
						require("neo-tree")
					end
				end,
			})
		end,
		opts = {
			sources = { "filesystem", "buffers", "git_status" },
			-- Rename/create prompts go through vim.ui.input (snacks.input) instead
			-- of neo-tree's own nui popup. The nui one is styled by neo-tree and
			-- looked nothing like the rest of the editor: its own border, its own
			-- title placement, its own colours. One input widget everywhere means
			-- the prompt is recognisable before it is read.
			use_popups_for_input = false,
			popup_border_style = "rounded", -- for the popups that remain (preview, help)
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
			renderers = {
				file = {
					{ "indent" },
					{ "icon" },
					{ "name", use_git_status_colors = true },
					{ "modified" }, -- dirty-buffer dot
					{ "diagnostics" },
					{ "git_status", highlight = "NeoTreeDimText" },
				},
			},
			default_component_configs = {
				modified = { symbol = "●", highlight = "NeoTreeModified" },
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
				Snacks.rename.on_rename_file(data.source, data.destination)
			end

			local events = require("neo-tree.events")
			opts.event_handlers = opts.event_handlers or {}
			vim.list_extend(opts.event_handlers, {
				{ event = events.FILE_MOVED, handler = on_move },
				{ event = events.FILE_RENAMED, handler = on_move },
			})
			local inputs = require("neo-tree.ui.inputs")
			---@param prompt string
			---@param default_value string?
			---@param callback fun(input: string?)
			---@param _options table? nui popup options, unused on this path
			---@param completion string?
			inputs.input = function(prompt, default_value, callback, _options, completion)
				local title = vim.trim((tostring(prompt):gsub("[\r\n]+", " ")))
				vim.ui.input({ prompt = title, default = default_value, completion = completion }, callback)
			end

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
	},
}

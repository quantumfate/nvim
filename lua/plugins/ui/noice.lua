--- Noice (lazy.nvim spec): floating cmdline, message and LSP-doc UI, plus
--- Tab/S-Tab scrolling of hover docs.

---@class NoiceConfig
---@field views table<string, NoiceView> View configurations for different UI elements
---@field cmdline NoiceCmdlineConfig Command-line interface configuration
---@field notify NoiceNotifyConfig Notification system configuration
---@field lsp NoiceLspConfig LSP integration settings
---@field routes NoiceRoute[] Message routing rules
---@field presets NoicePresets Pre-configured UI presets

---@class NoiceView
---@field enter? boolean Whether to enter the view automatically
---@field win_options? table Window-specific options
---@field border? table Border configuration
---@field position? table Position settings
---@field size? table Size configuration

---@class NoiceCmdlineConfig
---@field enabled boolean Whether to enable Noice cmdline UI
---@field view string View type for rendering cmdline
---@field format table<string, NoiceCmdlineFormat> Format configurations for different command types

---@class NoiceCmdlineFormat
---@field pattern string Pattern to match command
---@field icon string Icon to display
---@field lang? string Language for syntax highlighting
---@field kind? string Command kind classification

return {
	"folke/noice.nvim",
	event = "VimEnter",
	dependencies = { "MunifTanjim/nui.nvim" },
	opts = {
		views = {
			split = { enter = true },
			mini = {
				win_options = {
					winblend = 0,
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
				},
			},
			hover = {
				border = { style = "single" },
				win_options = { winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
			},
			popup = {
				border = { style = "single" },
				win_options = { winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
			},
			cmdline_popup = {
				position = { row = 5, col = "50%" },
				size = { width = 60, height = "auto" },
				win_options = { winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
			},
			popupmenu = {
				relative = "editor",
				position = { row = 8, col = "50%" },
				size = { width = 60, height = 10 },
				border = { style = "single", padding = { 0, 1 } },
				win_options = { winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" } },
			},
		},
		notify = { view = "mini" },
		lsp = {
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = true,
			},
			hover = { silent = true },
		},
		routes = {
			{
				filter = {
					event = "msg_show",
					any = {
						{ find = "%d+L, %d+B" },
						{ find = "; after #%d+" },
						{ find = "; before #%d+" },
					},
				},
				view = "mini",
			},
		},
		presets = {
			bottom_search = true,
			command_palette = true,
			long_message_to_split = true,
			inc_rename = true,
			lsp_doc_border = true,
		},
	},
	keys = {
		{ "<leader>N", "", desc = "+noice" },
		{
			"<leader>Nh",
			function()
				require("noice").cmd("history")
			end,
			desc = "Noice History",
		},
		{
			"<leader>Na",
			function()
				require("noice").cmd("all")
			end,
			desc = "Noice All",
		},
		{
			"<leader>Nd",
			function()
				require("noice").cmd("dismiss")
			end,
			desc = "Dismiss All",
		},
		{
			"<leader>Nt",
			function()
				require("noice").cmd("pick")
			end,
			desc = "Noice Picker (Telescope/FzfLua)",
		},
	},
	--- Starts noice and binds Tab/S-Tab to scroll hover docs (falling back to <c-k>).
	config = function(_, opts)
		-- Drop noise from lazy's own startup buffer before noice takes over.
		if vim.o.filetype == "lazy" then
			vim.cmd([[messages clear]])
		end
		require("noice").setup(opts)

		-- Scroll LSP hover docs; when there is none, fall through to <c-k>.
		local function scroll_docs(delta)
			return function()
				if not require("noice.lsp").scroll(delta) then
					return "<c-k>"
				end
			end
		end
		vim.keymap.set({ "n", "i", "s" }, "<Tab>", scroll_docs(2), { silent = true, expr = true })
		vim.keymap.set({ "n", "i", "s" }, "<S-Tab>", scroll_docs(-2), { silent = true, expr = true })
	end,
}

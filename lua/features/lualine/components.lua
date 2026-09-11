--- Lualine component definitions (branch, diagnostics, lsp, path, ...).
--- Reads two config-wide globals: `icons` (_G.icons) and `Snacks`.
local util = require("features.lualine.util")

--- Catppuccin Macchiato, read once. Used for the conditional components below.
local P = require("catppuccin.palettes").get_palette("macchiato")

--- Colour rule for the statusline:
---   * always-present components (path, location, progress, lsp, filetype)
---     stay in the theme greys — they are furniture, and furniture that shouts
---     every second stops carrying information at all;
---   * RARE components — the ones that appear only when something is true —
---     get a saturated palette colour each, so their appearance is the signal.
---     One hue per condition, so you learn "peach = debugger" rather than
---     reading the label.
---@param hex string Palette colour
---@return fun(): table lualine color spec
local function only(hex)
	return function()
		return { fg = hex }
	end
end

--- Below this window width, wide components hide themselves.
local window_width_limit = 150

--- Predicates gating when components render.
local conditions = {
	buffer_not_empty = function()
		return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
	end,
	hide_in_width = function()
		return vim.o.columns > window_width_limit
	end,
	no_clients = function()
		local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
		return #buf_clients == 0
	end,
	buffer_is_terminal = function()
		return vim.bo.buftype == "terminal"
	end,
}

local fmt = string.format

--- Current git branch from the gitsigns buffer state, or nil.
local function gitsigns_head()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return gitsigns.head
	end
end

return {
	mode = {
		"mode",
		-- The bar's left margin. It matches kitty's side padding, so the first
		-- glyph of the statusline lines up with the window's air instead of
		-- starting hard against the terminal edge.
		padding = { left = 2, right = 1 },
		cond = nil,
		---@param displayed string
		---@param _ table
		fmt = function(displayed, _)
			return util.unified_format(displayed)
		end,
	},
	branch = {
		"branch",
		source = gitsigns_head,
		icon = icons.git.Branch,
		fmt = function(displayed, _)
			local s = util.shorten_branch_name(displayed, 50)
			return util.unified_format(s)
		end,
	},
	root = {
		function()
			local root = require("lib.root").get()
			local name = vim.fn.fnamemodify(root, ":t")
			return icons.ui.FolderOpen .. " " .. name
		end,
		padding = { left = 2, right = 1 },
		cond = function()
			return not conditions.buffer_is_terminal() and conditions.hide_in_width() and not conditions.no_clients()
		end,
	},
	path = {
		require("features.lualine.util").get_path(),
		padding = { left = 0, right = 2 },
		-- An output pane has no path worth showing; `lang_output` names it instead.
		cond = function()
			return vim.b.lang_output ~= true
		end,
	},
	diff = {
		"diff",
		symbols = {
			added = icons.git.LineAdded,
			modified = icons.git.LineModified,
			removed = icons.git.LineRemoved,
		},
		source = function()
			local gitsigns = vim.b.gitsigns_status_dict
			if gitsigns then
				return {
					added = gitsigns.added,
					modified = gitsigns.changed,
					removed = gitsigns.removed,
				}
			end
		end,
		padding = { left = 2, right = 2 },
	},
	python_env = {
		color = only(P.green), -- a virtualenv is active
		function()
			if vim.bo.filetype == "python" then
				local venv = os.getenv("CONDA_DEFAULT_ENV") or os.getenv("VIRTUAL_ENV")
				if venv then
					local icons = require("nvim-web-devicons")
					local py_icon, _ = icons.get_icon(".py")
					return string.format(py_icon .. " (%s)", util.env_cleanup(venv))
				end
			end
			return ""
		end,
		padding = { left = 2, right = 2 },
	},
	diagnostics = {
		"diagnostics",
		symbols = {
			error = icons.diagnostics.Error,
			warn = icons.diagnostics.Warning,
			info = icons.diagnostics.Information,
			hint = icons.diagnostics.Hint,
		},
		cond = conditions.hide_in_width,
		padding = { left = 2, right = 2 },
	},
	lsp = {
		function()
			local buf_clients = vim.lsp.get_clients({
				bufnr = vim.api.nvim_get_current_buf(),
			})
			if #buf_clients == 0 then
				return ""
			end

			-- add client
			local lsps = {}
			for _, client in pairs(buf_clients) do
				if client.name ~= "null-ls" then
					table.insert(lsps, client.name)
				end
			end
			if #lsps == 0 then
				return ""
			end
			return util.unique_list_string_format(lsps)
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 3, right = 2 },
	},
	location = {
		"location",
		fmt = function(string, _)
			return fmt("%s", string)
		end,
		padding = { left = 2, right = 2 },
		cond = function()
			return not conditions.buffer_is_terminal()
		end,
	},
	progress = {
		"progress",
		fmt = function()
			return "%P/%L"
		end,
		cond = function()
			return not conditions.buffer_is_terminal()
		end,
	},
	spaces = {
		function()
			local shiftwidth = vim.bo[0].shiftwidth
			return icons.ui.Tab .. shiftwidth
		end,
		padding = 1,
	},
	encoding = {
		"o:encoding",
		fmt = string.upper,
		cond = conditions.hide_in_width,
		padding = { left = 2, right = 2 },
	},
	filetype = {
		"filetype",
		cond = nil,
		padding = { left = 2, right = 1 },
		icon_only = true,
	},
	searchcount = {
		color = only(P.yellow), -- an active search
		function()
			local sc = vim.fn.searchcount({ maxcount = 999 })
			if sc.total == 0 then
				return ""
			end
			return sc.current .. "/" .. sc.total
		end,
		cond = function()
			return vim.v.hlsearch == 1
		end,
		padding = { left = 2, right = 1 },
	},
	macrorecording = {
		color = only(P.red), -- recording: the one state you must not miss
		{
			function()
				local reg = vim.fn.reg_recording()
				if reg ~= "" then
					return "󰑋 @" .. reg
				end
				return ""
			end,
		},
		padding = { left = 2, right = 1 },
	},
	wordcount = {
		color = only(P.sky), -- prose buffers only
		function()
			return "󰈭 " .. vim.fn.wordcount().words
		end,
		cond = function()
			return vim.tbl_contains({ "markdown", "text", "txt" }, vim.bo.filetype)
		end,
	},
	navic = {
		function()
			return require("nvim-navic").get_location()
		end,
		cond = function()
			return require("nvim-navic").is_available() and conditions.hide_in_width()
		end,
		padding = { left = 2 },
	},
	command_status = {
		function()
			return require("noice").api.status.command.get()
		end,
		cond = function()
			return package.loaded["noice"] and require("noice").api.status.command.has()
		end,
		color = only(P.sapphire), -- noice command in flight
	},
	-- stylua: ignore
	mode_status = {
		function() return require("noice").api.status.mode.get() end,
		cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
		color = only(P.teal), -- noice mode (pending operator, etc.)
	},
	-- stylua: ignore
	debug_status = {
		function() return "" .. require("dap").status() end,
		cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
		color = only(P.peach), -- debugger attached
	},
	-- stylua: ignore
	updates_available = {
		require("lazy.status").updates,
		cond = require("lazy.status").has_updates,
		color = only(P.lavender), -- plugin updates waiting
	},
	harpoon = {
		color = only(P.maroon), -- this file is on the harpoon list
		function()
			local harpoon = require("harpoon")
			local list = harpoon:list()
			local current = vim.fn.expand("%:p:.")

			for i, item in ipairs(list.items) do
				if item.value == current then
					return "󰛢 " .. i
				end
			end
			return ""
		end,
		cond = function()
			return package.loaded["harpoon"] ~= nil
		end,
	},
	remote_nvim = {
		color = only(P.pink), -- editing on another host
		function()
			return vim.g.remote_neovim_host and ("Remote: %s"):format(vim.uv.os_gethostname()) or ""
		end,
		padding = { right = 1, left = 1 },
		cond = function()
			return conditions.hide_in_width()
		end,
	},
	-- A background compile is invisible otherwise: `vim.system` keeps the editor
	-- usable, which also means a slow `cargo rustc` looks exactly like a keypress that
	-- did not register.
	lang_job = {
		function()
			return require("features.lang.jobs").status()
		end,
		cond = function()
			return require("features.lang.jobs").active()
		end,
		color = only(P.mauve),
	},
	-- Output panes carry a rendering of another buffer, and their path component would
	-- show the scratch name. The title the view was opened under is the useful answer,
	-- and it doubles as the label a split cannot get from a border.
	lang_output = {
		function()
			return "  " .. (vim.b.lang_output_title or "output")
		end,
		cond = function()
			return vim.b.lang_output == true
		end,
		color = only(P.mauve),
	},
	view = {
		function()
			return require("features.workspace").dock().current() or ""
		end,
		-- Only rendered while a panel view is open, so the colour marks the
		-- edgy layout as active the same way the panel icons do.
		cond = function()
			return require("features.workspace").dock().current() ~= nil
		end,
		color = only(P.mauve), -- an edgy panel view is open
	},
	trouble = require("trouble").statusline({
		mode = "lsp_document_symbols",
		groups = {},
		title = false,
		filter = { range = true },
		format = "{kind_icon}{symbol.name:Normal}",
		-- The following line is needed to fix the background color
		-- Set it to the lualine section you want to use
		hl_group = "lualine_x_normal",
	}),
}

--- Editor settings: applies core vim options, filetypes, and diagnostic display.

--- Baseline vim options applied on startup. See https://neovim.io/doc/user/quickref.html#option-list
---@type table<string, any>
local default_options = {
	backup = false, -- creates a backup file
	clipboard = "unnamedplus", -- allows neovim to access the system clipboard
	cmdheight = 1, -- more space in the neovim command line for displaying messages
	completeopt = { "menuone", "noselect" },
	conceallevel = 0, -- so that `` is visible in markdown files
	fileencoding = "utf-8", -- the encoding written to a file
	foldmethod = "manual", -- folding, set to "expr" for treesitter based folding
	foldexpr = "", -- set to "nvim_treesitter#foldexpr()" for treesitter based folding
	guifont = "monospace:h17", -- the font used in graphical neovim applications
	hidden = true, -- required to keep multiple buffers and open multiple buffers
	hlsearch = true, -- highlight all matches on previous search pattern
	ignorecase = true, -- ignore case in search patterns
	mouse = "a", -- allow the mouse to be used in neovim
	pumheight = 10, -- pop up menu height
	showmode = false, -- we don't need to see things like -- INSERT -- anymore
	-- showtabline = -1, -- always show tabs
	smartcase = true, -- smart case
	splitbelow = true, -- force all horizontal splits to go below current window
	splitright = true, -- force all vertical splits to go to the right of current window
	swapfile = true, -- creates a swapfile
	termguicolors = true, -- set term gui colors (most terminals support this)
	timeoutlen = 100, -- time to wait for a mapped sequence to complete (in milliseconds)
	title = true, -- set the title of window to the value of the titlestring
	-- opt.titlestring = "%<%F%=%l/%L - nvim" -- what the title of the window will be set to
	undofile = true, -- enable persistent undo
	updatetime = 100, -- faster completion
	writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
	expandtab = true, -- convert tabs to spaces
	shiftwidth = 2, -- the number of spaces inserted for each indentation
	tabstop = 2, -- insert 2 spaces for a tab
	cursorline = true, -- highlight the current line
	number = true, -- set numbered lines
	numberwidth = 4, -- set number column width to 2 {default 4}
	signcolumn = "yes", -- always show the sign column, otherwise it would shift the text each time
	wrap = false, -- display lines as one long line
	scrolloff = 8, -- minimal number of screen lines to keep above and below the cursor.
	sidescrolloff = 8, -- minimal number of screen lines to keep left and right of the cursor.
	showcmd = false,
	ruler = false,
	laststatus = 3,
	relativenumber = true,
}

-- Append-style options that must extend (not overwrite) their defaults.
vim.opt.spelllang:append("cjk") -- skip spellcheck for CJK (unsupported by vim's algorithm)
vim.opt.shortmess:append("c") -- silence ins-completion-menu messages
vim.opt.shortmess:append("I") -- silence the default intro message
vim.opt.whichwrap:append("<,>,[,],h,l")

for k, v in pairs(default_options) do
	vim.opt[k] = v
end

-- Register extra filetype detection by extension and filename pattern.
vim.filetype.add({
	extension = {
		tex = "tex",
		zir = "zir",
	},
	pattern = {
		["[jt]sconfig.*.json"] = "jsonc",
	},
})

--- Diagnostic display: gutter signs, virtual text, and float styling.
--- `icons` is the global set in config/init.lua.
local default_diagnostic_config = {
	signs = {
		active = true,
		values = {
			{
				name = "DiagnosticSignError",
				text = icons.diagnostics.Error,
			},
			{
				name = "DiagnosticSignWarn",
				text = icons.diagnostics.Warning,
			},
			{
				name = "DiagnosticSignHint",
				text = icons.diagnostics.Hint,
			},
			{
				name = "DiagnosticSignInfo",
				text = icons.diagnostics.Information,
			},
		},
	},
	virtual_text = true,
	update_in_insert = false,
	underline = true,
	severity_sort = true,
	float = {
		focusable = true,
		style = "minimal",
		border = "strict",
		source = "always",
		header = "",
		prefix = "",
	},
}

vim.diagnostic.config(default_diagnostic_config)

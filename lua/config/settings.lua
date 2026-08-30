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

	-- --- Space -----------------------------------------------------------
	-- The same aesthetic as the terminal surface (kitty + both tmux bars):
	-- one accent, flat chrome, and air where the eye needs a boundary.
	--
	-- Division of labour: font size and LINE HEIGHT are cell-grid properties
	-- and belong to kitty (modify_font cell_height, see system-config's zsh
	-- role) — a terminal neovim cannot change how tall a text row is. What
	-- neovim owns is everything inside the viewport: gutters, borders, popups.
	numberwidth = 5, -- wider number gutter: digits stop touching the text
	signcolumn = "yes:2", -- two sign slots = a permanent blank lane between gutter and code
	pumheight = 12, -- a taller completion popup scrolls less
	pumblend = 0, -- popups fully opaque; translucency over code is noise
	winblend = 0,
	cursorlineopt = "number", -- mark the line in the gutter, do not paint a bar across the code
	winborder = "rounded", -- every float gets the same border (nvim 0.11+)
	fillchars = {
		eob = " ", -- no "~" column past the end of the buffer
		vert = " ", -- splits are separated by whitespace, not by a drawn rule
		horiz = " ",
		horizup = " ",
		horizdown = " ",
		vertleft = " ",
		vertright = " ",
		verthoriz = " ",
		fold = " ",
	},
}

-- Append-style options that must extend (not overwrite) their defaults.
vim.opt.spelllang:append("cjk") -- skip spellcheck for CJK (unsupported by vim's algorithm)
vim.opt.shortmess:append("c") -- silence ins-completion-menu messages
vim.opt.shortmess:append("I") -- silence the default intro message
vim.opt.whichwrap:append("<,>,[,],h,l")

for k, v in pairs(default_options) do
	vim.opt[k] = v
end

--- Markers that identify the root of an Ansible project. `roles/` and `inventory/` are
--- deliberately absent: those names show up in unrelated repos too.
local ansible_root_markers = { "ansible.cfg", ".ansible-lint", "galaxy.yml", "site.yml", "requirements.yml" }

--- Cached per directory: this runs for every plain-YAML buffer, and an upward walk each
--- time is wasteful when a project's files share a handful of directories.
---@type table<string, boolean>
local ansible_root_cache = {}

--- Whether `path` sits inside a tree that looks like an Ansible project.
---@param path string Absolute file path
---@return boolean
local function in_ansible_project(path)
	local dir = vim.fs.dirname(path)
	if ansible_root_cache[dir] == nil then
		local found = vim.fs.find(ansible_root_markers, { upward = true, path = dir, stop = vim.uv.os_homedir() })[1]
		ansible_root_cache[dir] = found ~= nil
	end
	return ansible_root_cache[dir]
end

-- Register extra filetype detection by extension, filename, and path pattern.
vim.filetype.add({
	extension = {
		tex = "tex",
		zir = "zir",
		--- Jinja templates have no filetype of their own. Detect the rendered file's type from
		--- the name with `.j2` stripped (nginx.conf.j2 -> conf) so templates are highlighted at
		--- all; fall back to a jinja-aware dialect when the stem says nothing.
		---@param path string
		---@return string
		j2 = function(path)
			local stripped = path:gsub("%.j2$", "")
			return vim.filetype.match({ filename = stripped }) or "htmldjango"
		end,
	},
	filename = {
		["playbook.yml"] = "yaml.ansible",
		["playbook.yaml"] = "yaml.ansible",
		["site.yml"] = "yaml.ansible",
		["site.yaml"] = "yaml.ansible",
		["ansible.cfg"] = "dosini",
	},
	pattern = {
		["[jt]sconfig.*.json"] = "jsonc",
		-- Standard Ansible role/playbook layout.
		[".*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/group_vars/.*/.*%.ya?ml"] = "yaml.ansible",
		[".*/playbook.*%.ya?ml"] = "yaml.ansible",
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/meta/.*%.ya?ml"] = "yaml.ansible",
		[".*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/molecule/.*%.ya?ml"] = "yaml.ansible",
		[".*/inventory/.*%.ya?ml"] = "yaml.ansible",
		[".*galaxy.*%.ya?ml"] = "yaml.ansible",
	},
})

-- nvim only consults string-valued patterns, never content functions, for buffered files.
-- So loose playbooks that miss the layout patterns above get claimed by sniffing the first
-- lines for real playbook keys; untouched YAML is left as plain "yaml".
vim.api.nvim_create_autocmd("FileType", {
	pattern = "yaml",
	callback = function(ev)
		local buf = ev.buf
		if vim.bo[buf].filetype ~= "yaml" then
			return
		end
		local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, 40, false)
		if not ok then
			return
		end
		local seen, hits = {}, 0
		for _, l in ipairs(lines) do
			local key = l:match("^%s*%-?%s*([%a_][%w_]*):")
			if key and not seen[key] then
				seen[key] = true
				if
					key == "hosts"
					or key == "roles"
					or key == "tasks"
					or key == "handlers"
					or key == "become"
					or key == "gather_facts"
					or key == "pre_tasks"
					or key == "post_tasks"
				then
					hits = hits + 1
				end
			end
		end
		if hits >= 2 then
			vim.bo[buf].filetype = "yaml.ansible"
			return
		end

		-- No playbook shape, but files under an Ansible project root (requirements.yml,
		-- inventories, loose vars files) are still ansiblels' and ansible-lint's business.
		local path = vim.api.nvim_buf_get_name(buf)
		if path ~= "" and in_ansible_project(path) then
			vim.bo[buf].filetype = "yaml.ansible"
		end
	end,
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

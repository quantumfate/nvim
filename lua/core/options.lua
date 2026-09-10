--- Editor options.
---
--- Set directly rather than looped over a table: `pairs` order is undefined, which
--- matters for interdependent options, and the table could not express the
--- append-style options below without a second code path anyway.

local opt = vim.opt

-- Files and state
opt.backup = false
opt.writebackup = false
opt.swapfile = true
opt.undofile = true -- persistent undo across sessions
opt.fileencoding = "utf-8"

-- Editing
opt.clipboard = "unnamedplus"
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.completeopt = { "menuone", "noselect" }
opt.inccommand = "split" -- live preview of :s results
opt.mouse = "a"
opt.whichwrap:append("<,>,[,],h,l")

-- Search
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Timings
opt.timeoutlen = 300 -- room to finish a which-key sequence and the `-`/`_` bracket prefix
opt.updatetime = 100

-- Appearance
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.numberwidth = 5 -- wider gutter: digits stop touching the text
opt.signcolumn = "yes:2" -- two sign slots = a permanent blank lane between gutter and code
opt.cursorline = true
opt.cursorlineopt = "number" -- mark the line in the gutter, do not paint a bar across the code
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.conceallevel = 0 -- so that `` stays visible in markdown
opt.title = true
opt.guifont = "monospace:h17"

-- Command line and status. noice owns message display, so the cmdline needs no
-- reserved rows of its own; laststatus=3 means one global statusline.
opt.cmdheight = 0
opt.cmdwinheight = 20
opt.laststatus = 3
opt.showmode = false
opt.showcmd = false
opt.ruler = false
opt.shortmess:append("c") -- silence ins-completion-menu messages
opt.shortmess:append("I") -- silence the intro message

-- Popups and floats
opt.pumheight = 12
opt.pumblend = 0 -- popups fully opaque; translucency over code is noise
opt.winblend = 0
opt.winborder = "rounded" -- every float gets the same border (nvim 0.11+)

-- Folding is owned by nvim-ufo, which installs its own foldexpr on attach.
opt.foldmethod = "manual"
opt.foldexpr = ""

opt.spelllang:append("cjk") -- skip spellcheck for CJK (unsupported by vim's algorithm)

opt.fillchars = {
	eob = " ", -- no "~" column past the end of the buffer
	-- Splits carry a thin rule so a docked panel has a visible edge; the rule
	-- stays quiet through WinSeparator (one step off the background), not weight.
	vert = "│",
	horiz = "─",
	horizup = "┴",
	horizdown = "┬",
	vertleft = "┤",
	vertright = "├",
	verthoriz = "┼",
	fold = " ",
}

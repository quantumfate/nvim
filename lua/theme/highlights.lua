--- Every highlight this config sets by hand, written against the role contract in
--- theme/roles.lua rather than any one colorscheme's palette.
---
--- The three rules these encode, unchanged from when they were catppuccin-specific:
--- no fills, one accent, metadata in greys. Expressed as ramp steps they hold for any
--- scheme: ramp[1] is the editor background, ramp[2..4] are structure (indent guide,
--- border, separator), ramp[5..7] are metadata text, ramp[8] is content, and `accent`
--- marks the single active thing on screen.
---@class theme.highlights
local M = {}

--- Builds the highlight table for a set of roles.
---@param roles theme.Roles
---@return table<string, vim.api.keyset.highlight>
function M.build(roles)
	local r = require("theme.roles").to_hex(roles)

	return {
		-- Output panes keep the editor background. Tinting them made every rendering
		-- look washed out against the code beside it, and the border and title already
		-- say "this is not the file" without touching a single character's contrast.
		LangOutput = { bg = r.ramp[1] },
		LangOutputBorder = { fg = r.accent, bg = r.ramp[1] },
		-- The winbar title on a split, which has no border to carry the name.
		LangOutputTitle = { fg = r.accent, bg = r.ramp[1], bold = true },
		LangOutputTitleNC = { fg = r.ramp[6], bg = r.ramp[1] },
		-- The instructions the cursor's source line produced. The one place a fill is
		-- right: it marks a moving selection, not a permanent surface.
		LangOutputLinked = { bg = r.ramp[3] },

		-- Refactor preview. A plan is three kinds of information — what will change,
		-- what will not, and what was not checked — and they need to be told apart at a
		-- glance rather than read.
		RefactorPreviewTitle = { fg = r.accent, bold = true },
		RefactorPreviewFile = { fg = r.ramp[7], bold = true },
		RefactorPreviewConflict = { fg = r.err, bold = true },
		RefactorPreviewSkip = { fg = r.warn },
		RefactorPreviewUnchecked = { fg = r.info },
		RefactorPreviewAdded = { bg = r.ramp[3] },
		RefactorPreviewAddedSign = { fg = r.ok, bold = true },
		RefactorPreviewLnum = { fg = r.ramp[5] },
		RefactorPreviewElision = { fg = r.ramp[4] },
		RefactorPreviewHelp = { fg = r.ramp[6], bg = r.ramp[2] },

		-- Crash frames. The faulting one is the answer; the rest are the path to it.
		CrashFaultFrame = { bg = r.ramp[3], fg = r.err, bold = true },
		CrashFrame = { fg = r.ramp[7] },

		NormalFloat = { bg = r.ramp[1] },
		-- Borders are structure, not accent. They sit one step off the
		-- background (surface1) so a float reads as a separate surface
		-- without drawing a bright frame around it; mauve is reserved
		-- for the one active thing on screen.
		FloatBorder = { fg = r.ramp[3], bg = r.ramp[1] },
		FloatTitle = { fg = r.ramp[6], bg = r.ramp[1] },
		-- Splits get a real rule again: surface1 is one step off the
		-- background, enough to see where a docked panel starts and stops
		-- without framing the screen in colour.
		WinSeparator = { fg = r.ramp[3], bg = r.ramp[1] },
		BlinkCmpMenuBorder = { link = "FloatBorder" },

		BlinkCmpKindAvante = { fg = r.accent },
		BlinkCmpKindAvanteCmd = { fg = r.accent },
		BlinkCmpKindAvanteMention = { fg = r.accent },
		BlinkCmpKindAvanteShortcut = { fg = r.accent },

		-- Noice cmdline
		NoiceCmdline = { bg = r.ramp[1] },
		NoiceCmdlinePopup = { bg = r.ramp[1] },
		NoiceCmdlinePopupBorder = { link = "FloatBorder" },
		NoiceCmdlineIcon = { fg = r.accent, bg = r.ramp[1] },
		-- Noice other elements (if needed)
		NoicePopup = { bg = r.ramp[1] },
		NoicePopupBorder = { link = "FloatBorder" },
		NoiceMini = { bg = r.ramp[1] },
		NoiceConfirm = { bg = r.ramp[1] },
		NoiceConfirmBorder = { link = "FloatBorder" },
		-- Edgy window backgrounds and borders
		EdgyNormal = { bg = r.ramp[1] },
		EdgyWinBar = { fg = r.accent, bg = r.ramp[1], bold = true },
		EdgyWinBarInactive = { fg = r.ramp[5], bg = r.ramp[1] },
		EdgyTitle = { fg = r.ramp[6], bg = r.ramp[1] },
		EdgyTitleInactive = { fg = r.ramp[5], bg = r.ramp[1] },
		EdgyIcon = { fg = r.ramp[5], bg = r.ramp[1] },
		EdgyIconActive = { fg = r.accent, bg = r.ramp[1] },

		-- Trouble backgrounds (for the edgy panels)
		TroubleNormal = { bg = r.ramp[1] },
		TroubleNormalNC = { bg = r.ramp[1] },
		TroubleTitle = { fg = r.accent },
		TroubleIconDirectory = { fg = r.accent },
		TroubleCount = { fg = r.accent, bg = r.ramp[2] },

		-- The statusline and tabline own no background: they sit on the
		-- editor background and are set off by whitespace, like the tmux
		-- bar above them. Nothing about them should read as a "bar".
		StatusLine = { bg = r.ramp[1], fg = r.ramp[5] },
		StatusLineNC = { bg = r.ramp[1], fg = r.ramp[4] },
		TabLine = { bg = r.ramp[1], fg = r.ramp[5] },
		TabLineFill = { bg = r.ramp[1] },
		TabLineSel = { bg = r.ramp[1], fg = r.accent, bold = true },
		WinBar = { bg = r.ramp[1], fg = r.ramp[5] },
		WinBarNC = { bg = r.ramp[1], fg = r.ramp[4] },

		-- lazy.nvim UI. Its groups are `hi default` links into whatever the
		-- colorscheme happens to define — IncSearch for the home button,
		-- Visual for the active tab, CursorLine for the others — which is
		-- how the manager ended up with filled chips and a rainbow of
		-- load-reason colours. Redefined here on the same three rules as
		-- everything else: no fills, one accent, metadata in greys.
		LazyNormal = { bg = r.ramp[1], fg = r.ramp[8] },
		LazyH1 = { fg = r.accent, bg = r.ramp[1], bold = true },
		LazyH2 = { fg = r.ramp[7], bold = true },
		LazyButton = { fg = r.ramp[5], bg = r.ramp[1] },
		LazyButtonActive = { fg = r.accent, bg = r.ramp[1], bold = true },
		LazySpecial = { fg = r.ramp[4] },
		LazyDimmed = { fg = r.ramp[4] },
		LazyProp = { fg = r.ramp[4] },
		LazyValue = { fg = r.ramp[7] },
		LazyComment = { fg = r.ramp[5] },
		LazyLocal = { fg = r.ramp[6] },
		LazyDir = { fg = r.ramp[6] },
		LazyUrl = { fg = r.ramp[6] },
		LazyNoCond = { fg = r.ramp[5] },
		LazyProgressDone = { fg = r.accent },
		LazyProgressTodo = { fg = r.ramp[3] },
		LazyCommit = { fg = r.ramp[6] },
		LazyCommitIssue = { fg = r.ramp[6] },
		LazyCommitType = { fg = r.ramp[7], bold = true },
		LazyCommitScope = { fg = r.ramp[6], italic = true },

		-- Load reasons are metadata about metadata: one grey for all of
		-- them, so the plugin NAME is what the eye lands on in a list of
		-- seventy rows.
		LazyReasonCmd = { fg = r.ramp[5] },
		LazyReasonEvent = { fg = r.ramp[5] },
		LazyReasonFt = { fg = r.ramp[5] },
		LazyReasonImport = { fg = r.ramp[5] },
		LazyReasonKeys = { fg = r.ramp[5] },
		LazyReasonPlugin = { fg = r.ramp[5] },
		LazyReasonRequire = { fg = r.ramp[5] },
		LazyReasonRuntime = { fg = r.ramp[5] },
		LazyReasonSource = { fg = r.ramp[5] },
		LazyReasonStart = { fg = r.ramp[5] },

		-- snacks.input — same surfaces as every other float: quiet border,
		-- grey title, and the accent on the prompt icon alone, which is
		-- the one thing that says "type here".
		SnacksInputBorder = { link = "FloatBorder" },
		SnacksInputTitle = { fg = r.ramp[6], bg = r.ramp[1] },
		SnacksInputIcon = { fg = r.accent, bg = r.ramp[1] },
		SnacksInputNormal = { bg = r.ramp[1], fg = r.ramp[8] },

		-- Indent guides (snacks.indent). The guide is a ruler: it must be
		-- visible when looked for and invisible when not. surface0 sits
		-- barely above the background; only the enclosing scope steps up
		-- to surface2, so exactly one guide on screen is brighter.
		SnacksIndent = { fg = r.ramp[2] },
		SnacksIndentScope = { fg = r.ramp[4] },
		SnacksIndentChunk = { fg = r.ramp[4] },

		-- Dap
		DapStoppedLine = { bg = r.ramp[2] },
		DapUIScope = { fg = r.accent },
		DapUIType = { fg = r.accent },
		DapUIValue = { fg = r.ramp[8] },
		DapUIVariable = { fg = r.ramp[8] },
		DapUIModifiedValue = { fg = r.changed, bold = true },

		-- Neo-tree, mauve accent
		NeoTreeNormal = { bg = r.ramp[1] },
		NeoTreeNormalNC = { bg = r.ramp[1] },
		-- The tree is an edgy panel like the rest, so it carries the same
		-- quiet rule on its edge.
		NeoTreeWinSeparator = { link = "WinSeparator" },
		NeoTreeBorder = { link = "WinSeparator" },
		NeoTreeTitleBar = { fg = r.ramp[6], bg = r.ramp[1] },
		NeoTreeFloatBorder = { link = "FloatBorder" },
		NeoTreeFloatTitle = { fg = r.accent, bg = r.ramp[1] },
		NeoTreeTabInactive = { fg = r.ramp[5], bg = r.ramp[1] },
		NeoTreeTabActive = { fg = r.accent, bg = r.ramp[1], bold = true },
		NeoTreeTabSeparatorInactive = { fg = r.ramp[5], bg = r.ramp[1] },
		NeoTreeTabSeparatorActive = { fg = r.accent, bg = r.ramp[1] },

		-- Neo-tree file/folder icons and text
		NeoTreeDirectoryIcon = { fg = r.accent },
		NeoTreeDirectoryName = { fg = r.ramp[7] },
		NeoTreeFileName = { fg = r.ramp[8] },
		NeoTreeFileIcon = { fg = r.info },
		NeoTreeModified = { fg = r.changed },
		NeoTreeHiddenByName = { fg = r.ramp[5] },

		-- Neo-tree git status
		NeoTreeGitAdded = { fg = r.ok },
		NeoTreeGitConflict = { fg = r.err },
		NeoTreeGitDeleted = { fg = r.err },
		NeoTreeGitIgnored = { fg = r.ramp[5] },
		NeoTreeGitModified = { fg = r.warn },
		NeoTreeGitUnstaged = { fg = r.err },
		NeoTreeGitUntracked = { fg = r.ok },
		NeoTreeGitStaged = { fg = r.ok },

		-- Neo-tree symbols and UI elements
		NeoTreeSymbolicLinkTarget = { fg = r.hint },
		NeoTreeRootName = { fg = r.ramp[6], bold = true },
		NeoTreeIndentMarker = { fg = r.ramp[5] },
		NeoTreeExpander = { fg = r.accent },
		NeoTreeDimText = { fg = r.ramp[5] },

		-- Neo-tree window picker
		NeoTreeEndOfBuffer = { fg = r.ramp[1] },

		-- Neo-tree buffers source
		NeoTreeBufferNumber = { fg = r.ramp[6] },

		-- Neo-tree preview
		NeoTreePreview = { bg = r.ramp[1] },
		NeoTreeCursorLine = { bg = r.ramp[2] },
		Pmenu = { fg = r.accent, bg = r.ramp[1] },
		PmenuSel = { bg = r.accent, fg = r.ramp[1] },
		PmenuThumb = { fg = r.accent, bg = r.ramp[1] },
		PmenuSbar = { fg = r.accent, bg = r.ramp[1] },

		Normal = { fg = r.ramp[8], bg = r.ramp[1] },
		Special = { fg = r.accent, bg = r.ramp[1] },
		Visual = { bg = r.ramp[2] },
		CursorLine = { bg = r.ramp[1] },

		-- Multicursor. Secondary cursors are metadata (grey), like line numbers —
		-- the caret that stays when the session ends is the one active thing, so
		-- only the main cursor's preview takes the accent. Locked cursors dim one
		-- step further than idle ones.
		MultiCursorCursor = { fg = r.ramp[1], bg = r.ramp[6], reverse = false },
		MultiCursorVisual = { bg = r.ramp[2] },
		MultiCursorSign = { fg = r.ramp[5] },
		MultiCursorMatchPreview = { fg = r.ramp[1], bg = r.ramp[6] },
		MultiCursorDisabledCursor = { fg = r.ramp[1], bg = r.ramp[4] },
		MultiCursorDisabledVisual = { fg = r.ramp[7], bg = r.ramp[1] },
		MultiCursorDisabledSign = { fg = r.ramp[3] },

		Directory = { fg = r.accent },
		-- Line numbers are a ruler, not content: they were mauve,
		-- which made the brightest colour on screen the one thing
		-- you never actually read. Only the cursor's line is accented.
		LineNr = { fg = r.ramp[4] },
		CursorLineNr = { fg = r.accent, bold = true },
		TroubleFilename = { fg = r.accent },
		Title = { fg = r.accent },

		MoreMsg = { fg = r.hint },
		NvimDapViewTabFill = { bg = r.ramp[1] },
		NvimDapViewTab = { fg = r.ramp[6], bg = r.ramp[1] },
		NvimDapViewTabSelected = { fg = r.accent },
	}
end

--- Applies every highlight. Safe to call repeatedly; that is how it stays in step
--- with whatever scheme was loaded last.
---@param roles theme.Roles
function M.apply(roles)
	for group, spec in pairs(M.build(roles)) do
		vim.api.nvim_set_hl(0, group, spec)
	end
end

return M

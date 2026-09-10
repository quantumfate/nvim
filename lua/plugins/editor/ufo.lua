--- nvim-ufo: richer code folding. Prefers the LSP provider so folds carry a
--- `kind` (imports/comment/region); treesitter and indent are fallbacks.
---@class plugins.editor.ufo

--- True when a treesitter parser is available for `ft`. Uses `language.add`,
--- which resolves the parser without parsing the buffer.
---@param ft string
---@return boolean
local function has_parser(ft)
	local lang = vim.treesitter.language.get_lang(ft) or ft
	return pcall(vim.treesitter.language.add, lang)
end

--- ufo resolves exactly two providers - `providers[1]` and `providers[2]` - and
--- catches `UfoFallbackException` only from the first. A provider that can raise
--- it therefore must never sit in the fallback slot: treesitter raises for
--- `buftype=nofile` buffers such as the cmdline window, and indent is the only
--- provider that never raises.
---
--- To still get lsp -> treesitter -> indent, the first slot is a function that
--- chains lsp and treesitter itself. Rejecting with UfoFallbackException from
--- either one leaves ufo's own handling to fall through to indent.
---@param bufnr integer
---@return unknown promise resolving to the fold ranges
local function lsp_then_treesitter(bufnr)
	local promise = require("promise")
	return promise
		.resolve()
		:thenCall(function()
			return require("ufo.provider.lsp").getFolds(bufnr)
		end)
		:catch(function(reason)
			if type(reason) == "string" and reason:match("UfoFallbackException") then
				return require("ufo.provider.treesitter").getFolds(bufnr)
			end
			return promise.reject(reason)
		end)
end

return {
	"kevinhwang91/nvim-ufo",
	dependencies = { "kevinhwang91/promise-async" },
	event = "BufReadPost",
	-- Ufo needs folds open and a fold column; set the global fold options it depends on.
	init = function()
		vim.o.foldcolumn = "1"
		vim.o.foldlevel = 99
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true
	end,
	---@type UfoConfig
	opts = {
		--- Pick a fold provider per buffer. ufo reads only providers[1] (main) and
		--- providers[2] (fallback), so the list is always exactly two entries, and
		--- the fallback is always indent - see lsp_then_treesitter above.
		--- LSP leads because it is the only provider that reports a fold `kind`,
		--- which is what close_fold_kinds_for_ft and `zr` act on.
		---@param bufnr integer
		---@param filetype string
		---@param buftype string
		---@return string|string[]
		provider_selector = function(bufnr, filetype, buftype)
			local provider_by_filetype = {
				vim = "indent",
				python = { "indent" },
				git = "",
				help = "",
				alpha = "",
				dashboard = "",
			}

			if provider_by_filetype[filetype] then
				return provider_by_filetype[filetype]
			end

			return has_parser(filetype) and { lsp_then_treesitter, "indent" } or { "lsp", "indent" }
		end,
		open_fold_hl_timeout = 150,
		-- Fold kinds come only from the LSP provider.
		close_fold_kinds_for_ft = {
			default = { "imports", "comment" },
			python = { "imports" },
			javascript = { "imports", "comment" },
			typescript = { "imports", "comment" },
			lua = { "imports", "comment" },
			go = { "imports" },
			rust = { "imports", "comment" },
		},
		preview = {
			win_config = {
				border = "single",
				winhighlight = "Normal:NormalFloat",
				winblend = 0,
			},
			mappings = {
				scrollU = "<C-k>",
				scrollD = "<C-j>",
				jumpTop = "[",
				jumpBot = "]",
			},
		},
		-- Render folded-line virtual text, truncating to width and appending a "󰁂 <n>" count suffix.
		---@param virtText table[] Highlighted { text, hlGroup } chunks of the fold's first line
		---@param lnum integer First line of the fold
		---@param endLnum integer Last line of the fold
		---@param width integer Available column width
		---@param truncate fun(text: string, width: integer): string
		---@return table[]
		fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
			local newVirtText = {}
			local suffix = (" 󰁂 %d "):format(endLnum - lnum)
			local sufWidth = vim.fn.strdisplaywidth(suffix)
			local targetWidth = width - sufWidth
			local curWidth = 0

			for _, chunk in ipairs(virtText) do
				local chunkText = chunk[1]
				local chunkWidth = vim.fn.strdisplaywidth(chunkText)
				if targetWidth > curWidth + chunkWidth then
					table.insert(newVirtText, chunk)
				else
					chunkText = truncate(chunkText, targetWidth - curWidth)
					local hlGroup = chunk[2]
					table.insert(newVirtText, { chunkText, hlGroup })
					chunkWidth = vim.fn.strdisplaywidth(chunkText)
					-- Pad the suffix when truncated text falls short of the target width.
					if curWidth + chunkWidth < targetWidth then
						suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
					end
					break
				end
				curWidth = curWidth + chunkWidth
			end

			table.insert(newVirtText, { suffix, "MoreMsg" })
			return newVirtText
		end,
	},
	keys = {
		{ "zR", desc = "Open all folds" },
		{ "zM", desc = "Close all folds" },
		{ "zr", desc = "Open folds except kinds" },
		{ "zm", desc = "Close folds with" },
		{ "zK", desc = "Peek fold or hover" },
		{ "z]", desc = "Next closed fold" },
		{ "z[", desc = "Prev closed fold" },
		{ "z1", desc = "Close L1 folds" },
		{ "z2", desc = "Close L2 folds" },
		{ "z3", desc = "Close L3 folds" },
	},
	-- Set up ufo and bind its fold controls through which-key.
	config = function(_, opts)
		require("ufo").setup(opts)

		require("which-key").add({
			{
				"zR",
				function()
					require("ufo").openAllFolds()
				end,
				desc = "Open all folds",
			},
			{
				"zM",
				function()
					require("ufo").closeAllFolds()
				end,
				desc = "Close all folds",
			},
			{
				"zr",
				function()
					require("ufo").openFoldsExceptKinds()
				end,
				desc = "Open folds except kinds",
			},
			{
				"zm",
				function()
					require("ufo").closeFoldsWith()
				end,
				desc = "Close folds with",
			},
			{
				"zK",
				function()
					-- Returns the preview winid, or nil when the cursor is not on a
					-- closed fold - fall through to hover so the key is never inert.
					if not require("ufo").peekFoldedLinesUnderCursor() then
						vim.lsp.buf.hover()
					end
				end,
				desc = "Peek fold or hover",
			},
			{
				"z]",
				function()
					require("ufo").goNextClosedFold()
				end,
				desc = "Next closed fold",
			},
			{
				"z[",
				function()
					require("ufo").goPreviousClosedFold()
				end,
				desc = "Prev closed fold",
			},
			{
				"z1",
				function()
					require("ufo").closeFoldsWith(1)
				end,
				desc = "Close L1 folds",
			},
			{
				"z2",
				function()
					require("ufo").closeFoldsWith(2)
				end,
				desc = "Close L2 folds",
			},
			{
				"z3",
				function()
					require("ufo").closeFoldsWith(3)
				end,
				desc = "Close L3 folds",
			},
		})
	end,
}

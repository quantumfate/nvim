--- Enhanced code folding with treesitter and LSP integration
--- Provides intelligent folding with capability-aware provider selection and conditional keymaps
---@class plugins.editor.ufo
---@field setup fun(): nil

---@class UfoConfig
---@field provider_selector fun(bufnr: integer, filetype: string, buftype: string): string|string[] Provider selection function
---@field open_fold_hl_timeout integer Highlight timeout for opened folds in milliseconds
---@field close_fold_kinds_for_ft table<string, string[]> Fold kinds to close by filetype
---@field preview table Preview window configuration
---@field fold_virt_text_handler fun(virtText: table[], lnum: integer, endLnum: integer, width: integer, truncate: function): table[] Custom fold text handler

return {
	"kevinhwang91/nvim-ufo",
	dependencies = { "kevinhwang91/promise-async" },
	event = "BufReadPost",
	init = function()
		-- Configure folding options globally
		vim.o.foldcolumn = "1"
		vim.o.foldlevel = 99
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true
	end,
	---@type UfoConfig
	opts = {
		provider_selector = function(bufnr, filetype, buftype)
			-- Capability-aware provider selection
			local ftMap = {
				vim = "indent",
				python = { "indent" },
				git = "",
				help = "",
				alpha = "",
				dashboard = "",
			}

			-- Check if treesitter parser is available for this filetype
			local has_parser =
				pcall(vim.treesitter.language.inspect, vim.treesitter.language.get_lang(filetype) or filetype)

			if ftMap[filetype] then
				return ftMap[filetype]
			elseif has_parser then
				return { "treesitter", "indent" }
			else
				return { "indent" }
			end
		end,
		open_fold_hl_timeout = 150,
		close_fold_kinds_for_ft = {
			default = { "imports", "comment" },
			python = { "imports" },
			javascript = { "imports", "comment" },
			typescript = { "imports", "comment" },
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
					-- Pad if truncated text is shorter than target
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
		{ "zK", desc = "Peek fold" },
		{ "z1", desc = "Close L1 folds" },
		{ "z2", desc = "Close L2 folds" },
		{ "z3", desc = "Close L3 folds" },
	},
	config = function(_, opts)
		require("ufo").setup(opts)

		-- Register conditional keymaps via which-key
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
					require("ufo").peekFoldedLinesUnderCursor()
				end,
				desc = "Peek fold",
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

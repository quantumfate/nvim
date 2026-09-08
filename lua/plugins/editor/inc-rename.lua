--- inc-rename.nvim: LSP rename with a live inline preview of the edit.
---@class plugins.editor.inc_rename

---@param preview_buf integer
---@param ft string
local function attach_treesitter(preview_buf, ft)
	if vim.b[preview_buf].inc_rename_ts then
		return
	end
	local lang = vim.treesitter.language.get_lang(ft)
	if not lang or not pcall(vim.treesitter.start, preview_buf, lang) then
		return
	end
	vim.b[preview_buf].inc_rename_ts = true
end

local function set_highlights()
	vim.api.nvim_set_hl(0, "IncRenameMatch", { link = "Substitute" })
end

return {
	"smjonas/inc-rename.nvim",
	event = "LspAttach",
	---@type inc_rename.UserConfig
	opts = {
		-- nil = cmdline input; noice's `inc_rename` preset renders the preview.
		-- Only "dressing"|"snacks" are valid alternatives.
		input_buffer_type = nil,
		preview_empty_name = false,
		show_message = true,
		hl_group = "IncRenameMatch",
		save_in_cmdline_history = true,
		--- Rename silently loads untouched files as buffers and edits them without
		--- writing, so gitsigns and neo-tree keep showing the pre-rename state.
		--- Persist every buffer the edit touched.
		---@param result lsp.WorkspaceEdit
		post_hook = function(result)
			local files = vim.tbl_count(result.changes or {})
			if files == 0 then
				files = #(result.documentChanges or {})
			end
			vim.cmd("wall")
			Snacks.notify.info(("Renamed and saved across %d file(s)"):format(files))
		end,
	},
	---@param opts inc_rename.UserConfig
	config = function(_, opts)
		local inc_rename = require("inc_rename")
		inc_rename.setup(opts)

		set_highlights()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("inc_rename_hl", { clear = true }),
			desc = "Restore IncRenameMatch after a colorscheme change",
			callback = set_highlights,
		})

		-- _populate_preview_buf runs on every keystroke with the split preview's
		-- buffer, which is the only place we can reach it.
		local populate = inc_rename._populate_preview_buf
		inc_rename._populate_preview_buf = function(preview_buf, buf_infos, preview_ns)
			local ft = vim.bo.filetype
			populate(preview_buf, buf_infos, preview_ns)
			attach_treesitter(preview_buf, ft)
		end
	end,
}

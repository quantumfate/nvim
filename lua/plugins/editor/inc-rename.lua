--- inc-rename.nvim: LSP rename with a live inline preview of the edit.
---@class plugins.editor.inc_rename

---@class IncRenameConfig
---@field input_buffer_type string|nil Buffer type for input ("dressing" or nil for cmdline)
---@field preview_empty_name boolean Whether to preview when name is empty
---@field show_message boolean Whether to show completion messages

return {
	"smjonas/inc-rename.nvim",
	event = "LspAttach",
	opts = {
		input_buffer_type = "noice",
		preview_empty_name = false,
		show_message = true,
	},
}

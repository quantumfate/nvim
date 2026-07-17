---@class LspKeymapConfig
---@field keys string Keymap sequence
---@field func? function|string Function to execute or command string
---@field cmd? string Command string (alternative to func)
---@field desc string Keymap description
---@field method? string LSP method for capability check
---@field mode? string|string[] Vim modes (default: "n")
---@field expr? boolean Whether the function returns a string to execute
---@field cond? fun(): boolean Additional condition check

--- Standard LSP keymaps, gated by capability in lspconfig's LspAttach handler.
--- Navigation entries drive the Snacks picker (global).
---@type LspKeymapConfig[]
local M = {
	-- Core navigation (using Snacks picker)
	{
		keys = "gd",
		func = function()
			Snacks.picker.lsp_definitions()
		end,
		desc = "Goto Definition",
		method = "textDocument/definition",
	},
	{
		keys = "gD",
		func = function()
			Snacks.picker.lsp_declarations()
		end,
		desc = "Goto Declaration",
		method = "textDocument/declaration",
	},
	{
		keys = "gr",
		func = function()
			Snacks.picker.lsp_references()
		end,
		desc = "References",
		method = "textDocument/references",
	},
	{
		keys = "gI",
		func = function()
			Snacks.picker.lsp_implementations()
		end,
		desc = "Goto Implementation",
		method = "textDocument/implementation",
	},
	{
		keys = "gy",
		func = function()
			Snacks.picker.lsp_type_definitions()
		end,
		desc = "Type Definition",
		method = "textDocument/typeDefinition",
	},

	-- Override Neovim 0.11 gr* defaults
	{
		keys = "grr",
		func = function()
			Snacks.picker.lsp_references()
		end,
		desc = "References",
		method = "textDocument/references",
	},
	{
		keys = "gri",
		func = function()
			Snacks.picker.lsp_implementations()
		end,
		desc = "Goto Implementation",
		method = "textDocument/implementation",
	},
	{
		keys = "grt",
		func = function()
			Snacks.picker.lsp_type_definitions()
		end,
		desc = "Type Definition",
		method = "textDocument/typeDefinition",
	},
	{
		keys = "grn",
		func = function()
			local modules = require("util.modules")
			if modules.is_loaded("inc-rename.nvim") then
				return ":IncRename " .. vim.fn.expand("<cword>")
			else
				vim.lsp.buf.rename()
				return ""
			end
		end,
		expr = true,
		desc = "Rename",
		method = "textDocument/rename",
	},
	{
		keys = "gra",
		func = vim.lsp.buf.code_action,
		desc = "Code Action",
		method = "textDocument/codeAction",
		mode = { "n", "v" },
	},
	{
		keys = "gO",
		func = function()
			Snacks.picker.lsp_symbols()
		end,
		desc = "Document Symbols",
		method = "textDocument/documentSymbol",
	},

	-- Documentation
	{
		keys = "K",
		func = function()
			if vim.bo.filetype == "rust" then
				vim.cmd.RustLsp({ "hover", "actions" })
			else
				vim.lsp.buf.hover()
			end
		end,
		desc = "Hover Documentation",
		method = "textDocument/hover",
	},
	{
		keys = "gK",
		func = vim.lsp.buf.signature_help,
		desc = "Signature Help",
		method = "textDocument/signatureHelp",
	},
	{
		keys = "<C-s>",
		func = vim.lsp.buf.signature_help,
		desc = "Signature Help",
		method = "textDocument/signatureHelp",
		mode = "i",
	},

	-- Code actions and refactoring (leader keymaps)
	{
		keys = "<leader>ca",
		func = function()
			if vim.bo.filetype == "rust" then
				vim.cmd.RustLsp("codeAction")
			else
				vim.lsp.buf.code_action()
			end
		end,
		desc = "Code Action",
		method = "textDocument/codeAction",
		mode = { "n", "v" },
	},
	{
		keys = "<leader>cr",
		func = function()
			local modules = require("util.modules")
			if modules.is_loaded("inc-rename.nvim") then
				return ":IncRename " .. vim.fn.expand("<cword>")
			else
				vim.lsp.buf.rename()
				return ""
			end
		end,
		expr = true,
		desc = "Rename",
		method = "textDocument/rename",
	},

	-- Diagnostics (always available)
	{
		keys = "<leader>cd",
		func = vim.diagnostic.open_float,
		desc = "Line Diagnostics",
	},
	{
		keys = "]d",
		func = function()
			vim.diagnostic.jump({ count = 1 })
		end,
		desc = "Next Diagnostic",
	},
	{
		keys = "[d",
		func = function()
			vim.diagnostic.jump({ count = -1 })
		end,
		desc = "Prev Diagnostic",
	},
}

return M

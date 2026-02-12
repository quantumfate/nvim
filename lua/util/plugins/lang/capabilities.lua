--- LSP capability matrix for reference and debugging
---@type table<string, table<string, boolean>>
local M = {
	lua_ls = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = false, -- Use stylua via conform
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = false,
	},
	basedpyright = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = false, -- Use black/ruff via conform
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = false,
	},
	gopls = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = true,
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = false,
	},
	rust_analyzer = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = true,
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = false,
	},
	ts_ls = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = false, -- Use prettier via conform
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = false,
	},
	clangd = {
		completion = true,
		hover = true,
		definition = true,
		references = true,
		rename = true,
		formatting = true,
		codeAction = true,
		inlayHints = true,
		switchSourceHeader = true,
	},
}

return M

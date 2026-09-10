--- zig.vim spec: official Zig filetype plugin. Keymaps live in features/lang/zig.lua.
return {
	"ziglang/zig.vim",
	ft = { "zig" },
	init = function()
		-- conform.nvim owns formatting via `zig fmt`; keep zig.vim's autosave hook off.
		vim.g.zig_fmt_autosave = 0
	end,
	-- The build/run/test/ast-check keymaps that used to live here are now the shared
	-- language actions in lua/features/lang/zig.lua, on <leader>b* like every other
	-- language. Nothing zig-specific remains except turning off the autosave hook.
}

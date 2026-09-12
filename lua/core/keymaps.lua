--- Every keymap that belongs to this config rather than to a plugin.
---
--- Plugin-owned bindings stay in their spec:
---   flash        — `s` / `S` / `r` / `R` label jumps  (plugins/editor/flash.lua)
---   textobjects  — `]f` `[c` motions, `<leader>m` swaps (plugins/editor/treesitter.lua)
---   mini.ai      — `af` `iv` `iu` textobjects          (plugins/lib/mini-ai.lua)
---   LSP          — `g*` navigation                     (plugins/lang/conf/keymaps.lua)

local map = vim.keymap.set

-- Windows ------------------------------------------------------------------

map("n", "<leader>wh", "<cmd>wincmd h<cr>", { desc = "Left" })
map("n", "<leader>wj", "<cmd>wincmd j<cr>", { desc = "Down" })
map("n", "<leader>wk", "<cmd>wincmd k<cr>", { desc = "Up" })
map("n", "<leader>wl", "<cmd>wincmd l<cr>", { desc = "Right" })
map("n", "<leader>wx", "<cmd>close<cr>", { desc = "Close" })

map("n", "<leader>wH", "<cmd>vertical resize +2<cr>", { desc = "Width +2" })
map("n", "<leader>wJ", "<cmd>resize +2<cr>", { desc = "Height +2" })
map("n", "<leader>wK", "<cmd>resize -2<cr>", { desc = "Height -2" })
map("n", "<leader>wL", "<cmd>vertical resize -2<cr>", { desc = "Width -2" })

map("n", "<leader>wv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>ws", "<cmd>split<cr>", { desc = "Horizontal split" })
map("n", "<leader>w=", "<cmd>wincmd =<cr>", { desc = "Balance" })

-- Swap with a neighbouring split (file buffers only, skips trouble/edgy/etc.)
for key, direction in pairs({ ["<"] = "h", [">"] = "l", ["-"] = "k", ["+"] = "j" }) do
	map("n", "<leader>w" .. key, function()
		require("features.win_swap").swap(direction)
	end, { desc = "Swap split " .. direction })
end

-- Scrolling and search ------------------------------------------------------

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

map("n", "<leader>sn", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map(
	"n",
	"<leader>ss",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Search and replace word under cursor" }
)

-- Lists ---------------------------------------------------------------------

map("n", "<C-k>", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
map("n", "<C-j>", "<cmd>cprev<cr>zz", { desc = "Prev quickfix item" })
map("n", "<leader>k", "<cmd>lnext<cr>zz", { desc = "Next location list item" })
map("n", "<leader>j", "<cmd>lprev<cr>zz", { desc = "Prev location list item" })

-- Editing -------------------------------------------------------------------

map("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })
map("x", "<leader>P", [["_dP]], { desc = "Paste without yanking selection" })
map({ "n", "v" }, "<leader>D", [["_d]], { desc = "Delete to black hole register" })
map("i", "<C-c>", "<Esc>", { desc = "Escape insert mode" })
map("n", "Q", "<nop>", { desc = "" })
map("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<cr>", { desc = "Open tmux sessionizer" })

-- Files ---------------------------------------------------------------------

map("n", "<leader>fr", function()
	vim.fn.system({ "wl-copy" }, require("lib.root").get_relative_fp())
end, { desc = "Copy file path relative of root to clipboard" })

-- Layout ------------------------------------------------------------------
--
-- This config is driven from the custom Dvorak layout in the system-config
-- playbook, where the QWERTY-era key pairs fall apart:
--   `[` is AE02 and `]` is AE09 — seven keys apart, opposite hands, both an
--   upward stretch, and nothing about them feels mirrored.
--
-- Rather than hunt for two mirrored keys (this layout has none free), direction
-- rides on Shift over a single home-row key. `-` is AC11, right pinky, home row,
-- and its native meaning (first non-blank of the previous line) is dead weight.
--
--   -  =  ]   next / forward        _  =  [   previous / backward
--
-- The alias is on the PREFIX, so every bracket mapping follows automatically,
-- including motions plugins add later. `[` and `]` keep working.
map({ "n", "x", "o" }, "-", "]", { remap = true, desc = "Next (bracket prefix)" })
map({ "n", "x", "o" }, "_", "[", { remap = true, desc = "Prev (bracket prefix)" })

-- Same rule one level up: mini.ai's edge motions move to `g-` / `g_`, with the
-- bracket spellings kept as aliases (see plugins/lib/mini-ai.lua).
map({ "n", "x", "o" }, "g]", "g-", { remap = true, desc = "Goto end of" })
map({ "n", "x", "o" }, "g[", "g_", { remap = true, desc = "Goto start of" })

-- Structural movement -------------------------------------------------------

-- Drag under the right hand's home row: d h t n sit where QWERTY puts h j k l,
-- so the four directions stay in one place instead of scattering across rows.
--   <A-d> left   <A-h> down   <A-t> up   <A-n> right
---@type table<string, table<string, [string, string]>> mode -> lhs -> { rhs, desc }
local drags = {
	n = {
		["<A-h>"] = { "<cmd>m .+1<cr>==", "Move line down" },
		["<A-t>"] = { "<cmd>m .-2<cr>==", "Move line up" },
	},
	i = {
		["<A-h>"] = { "<esc><cmd>m .+1<cr>==gi", "Move line down" },
		["<A-t>"] = { "<esc><cmd>m .-2<cr>==gi", "Move line up" },
	},
	x = {
		["<A-h>"] = { ":m '>+1<cr>gv=gv", "Move selection down" },
		["<A-t>"] = { ":m '<-2<cr>gv=gv", "Move selection up" },
	},
}

-- `<A-j>` / `<A-k>` stay as aliases; they collide with nothing in the new scheme.
local drag_aliases = { ["<A-h>"] = "<A-j>", ["<A-t>"] = "<A-k>" }

for mode, binds in pairs(drags) do
	for lhs, spec in pairs(binds) do
		map(mode, lhs, spec[1], { desc = spec[2] })
		map(mode, drag_aliases[lhs], spec[1], { desc = spec[2] })
	end
end

-- <A-n> / <A-d> used to run a raw treesitter parameter swap here. They now go through
-- the refactoring engine below, which swaps the call sites too.

--- Copies the textobject enclosing the cursor below itself.
---@param capture string
local function duplicate(capture)
	return function()
		require("features.ts_scope").duplicate(capture)
	end
end

map("n", "<leader>rd", duplicate("function.outer"), { desc = "Duplicate function" })
map("n", "<leader>rD", duplicate("class.outer"), { desc = "Duplicate class" })

-- Refactorings. Each one builds a plan, shows it, and applies only on confirm; see
-- lua/features/refactor/. `<leader>rr` opens the menu, the rest are direct.
---@param name string Key in refactor.ops
---@param opts? table
---@return fun()
local function refactor(name, opts)
	return function()
		require("features.refactor").ops[name].run(opts or {})
	end
end

map("n", "<leader>rr", function()
	require("features.refactor").select()
end, { desc = "Refactor menu" })

map("n", "<leader>ra", refactor("add_param"), { desc = "Add parameter" })
map("n", "<leader>rA", refactor("add_param", { force = true }), { desc = "Add parameter (force call sites)" })
map("n", "<leader>rx", refactor("remove_param"), { desc = "Remove parameter" })
-- `<leader>rn` stays with inc-rename (features/lsp/keymaps.lua), which binds it
-- buffer-locally on attach and gives a live cmdline preview. This is the wider one:
-- LSP rename plus the comment and string occurrences, through the plan preview.
map("n", "<leader>rN", refactor("rename"), { desc = "Rename incl. comments and strings" })
map("n", "<leader>rs", refactor("safe_delete"), { desc = "Safe delete" })
-- `<leader>rv` and `<leader>ri` stay with refactoring.nvim, which binds them
-- buffer-locally and supports motions. The engine's plan-based versions, which add a
-- preview and collision checks but no motion, are `:Refactor extract_variable` and
-- `:Refactor inline_variable`.
map("n", "<leader>rm", refactor("move_to_file"), { desc = "Move to file" })
map("n", "<leader>rS", refactor("server"), { desc = "Server refactorings" })
map("n", "<leader>ru", function()
	require("features.refactor.plan").undo()
end, { desc = "Undo last refactoring (all files)" })

-- Parameter order rides the same home-row cluster as the other structural moves.
map("n", "<A-n>", refactor("reorder_param_next"), { desc = "Move parameter right" })
map("n", "<A-d>", refactor("reorder_param_prev"), { desc = "Move parameter left" })

vim.api.nvim_create_user_command("SigAdd", function(opts)
	require("features.refactor").ops.add_param.run({
		spec = opts.args ~= "" and opts.args or nil,
		force = opts.bang,
	})
end, { nargs = "?", bang = true, desc = "Add parameter to the enclosing signature" })
